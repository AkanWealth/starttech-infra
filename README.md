# starttech-infra

Terraform and GitHub Actions for the StartTech platform on AWS: a React frontend on S3, a Go API on Amazon EKS, Redis on ElastiCache and MongoDB on Atlas. One CloudFront distribution serves both the frontend and the API.

The application code and its pipelines live in [starttech-application](../starttech-application).

## Architecture

```
                        https://<id>.cloudfront.net
                                    │
                      ┌─────────────┴─────────────┐
                      │   CloudFront distribution  │
                      └──────┬──────────────┬──────┘
          default (*)        │              │      /api/*  (no cache, all headers/cookies/query strings)
   origin S3-Frontend (OAC)  │              │      origin ALB-Backend (HTTP + X-Origin-Verify header)
                             ▼              ▼
              S3 starttech-frontend-   ALB (public subnets, CloudFront prefix list only)
              bucket-<account> (private)    │  :80 -> NodePort 30080
                                            ▼
                         EKS starttech-cluster / starttech-node-group (private subnets)
                            namespace starttech, deployment backend-api (:8080)
                                │                         │
                                ▼                         ▼
                ElastiCache starttech-redis        MongoDB Atlas
                (private database subnets)         (via NAT gateway)
```

### How the two frontend issues are solved

**SPA routing.** S3 has no object at `/todos` or `/profile`, so a page refresh there returns 403 (no `s3:ListBucket`) or 404. The distribution has `custom_error_response` blocks that rewrite both codes to `/index.html` with status `200`, and React Router then renders the right view.

**Mixed content.** The ALB only speaks HTTP. Instead of calling it from the HTTPS page, the browser calls relative paths such as `/api/v1/health` on the CloudFront domain. The `/api/*` cache behavior sends these to the `ALB-Backend` origin with caching disabled (`min_ttl = default_ttl = max_ttl = 0`). All headers, cookies and query strings are forwarded. Everything the browser sees is same-origin HTTPS.

## Repository layout

```
starttech-infra/
├── .github/workflows/infrastructure-deploy.yml   # fmt, validate, plan, apply on main
├── terraform/
│   ├── main.tf                    # providers, S3 backend, module wiring
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── networking/            # VPC, subnets, IGW, NAT, route tables, S3 endpoint
│       ├── eks/                   # cluster, node group, IAM roles, add-ons, backend ALB
│       ├── storage/               # S3 frontend bucket, ECR repository
│       ├── cdn/                   # CloudFront (S3-Frontend + ALB-Backend), OAC, bucket policy
│       ├── database/              # ElastiCache Redis
│       └── iam/                   # GitHub OIDC roles, start-tech-grader user
└── scripts/deploy-infrastructure.sh
```

## Resource names

| Resource | Name / identifier | Where |
|---|---|---|
| VPC | `starttech-vpc` (Name tag), `10.0.0.0/16` | `modules/networking/main.tf` |
| EKS cluster | `starttech-cluster` | `modules/eks/main.tf` |
| EKS managed node group | `starttech-node-group` (2 × `t3.medium`, min 2) | `modules/eks/main.tf` |
| S3 bucket | `starttech-frontend-bucket-<account id>` | `modules/storage/main.tf` |
| ECR repository | `starttech-backend-api` | `modules/storage/main.tf` |
| ElastiCache Redis | `starttech-redis` (`cache.t3.micro`, 1 node) | `modules/database/main.tf` |
| CloudFront S3 origin | `S3-Frontend` | `modules/cdn/main.tf` |
| CloudFront ALB origin | `ALB-Backend` | `modules/cdn/main.tf` |
| Backend container port | `8080` (NodePort `30080`) | application repo `k8s/` |
| Grader IAM user | `start-tech-grader` | `modules/iam/main.tf` |

## What gets created

**Networking**
- 2 public subnets (`10.0.1.0/24`, `10.0.2.0/24`), tagged `kubernetes.io/role/elb = 1`.
- 2 private subnets for the worker nodes (`10.0.11.0/24`, `10.0.12.0/24`), tagged `kubernetes.io/role/internal-elb = 1`.
- 2 private database subnets (`10.0.21.0/24`, `10.0.22.0/24`) with no internet route.
- Internet gateway, NAT gateway(s), and a free S3 gateway endpoint so ECR image pulls skip the NAT.

**EKS**
- Kubernetes 1.35 by default. Any version from 1.34 up is accepted; 1.34 leaves standard support in December 2026, and extended support costs more.
- API and audit logs go to CloudWatch with 30-day retention. Kubernetes secrets are envelope-encrypted with KMS.
- Managed node group on Amazon Linux 2023 with 2 to 4 `t3.medium` nodes.
- Control plane role: `AmazonEKSClusterPolicy`. Node role: `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonEKS_CNI_Policy`. Nothing else is attached.
- Managed add-ons: `vpc-cni`, `kube-proxy`, `coredns`, `eks-pod-identity-agent`.

**Backend ALB** (`modules/eks/alb.tf`)
- Terraform creates the ALB, so CloudFront can use its DNS name in the same `apply`. It forwards to the nodes on NodePort `30080`, which the `backend-api` Service exposes.
- Locked down two ways:
  1. The security group only allows the CloudFront origin-facing prefix list.
  2. The listener returns 403 unless the request carries the secret `X-Origin-Verify` header that CloudFront adds.

**Storage**
- The frontend bucket blocks all public access (`aws_s3_bucket_public_access_block`). Ownership is BucketOwnerEnforced, objects are encrypted, versioning is on, and the bucket policy denies non-TLS access.
- Only this distribution can read it, through OAC (`AWS:SourceArn` condition).
- ECR uses immutable tags, scan on push, and a lifecycle policy that keeps the last 30 images.

**Redis**
- One `cache.t3.micro` node in the database subnets. The security group allows port 6379 only from the EKS node security group.

**IAM**
- GitHub OIDC provider plus two roles, so GitHub holds no long-lived AWS keys:
  - `starttech-github-infra-deploy`: runs Terraform. AdministratorAccess, limited to `main` and the `production` environment of this repository.
  - `starttech-github-app-deploy`: ECR push, S3 sync, CloudFront invalidation, EKS describe, plus an EKS access entry.
- `start-tech-grader` user with the exact read-only grading policy in [`modules/iam/grader-policy.json`](terraform/modules/iam/grader-policy.json).

## First deployment

### Prerequisites
- Terraform >= 1.10 (the S3 backend's native locking needs it)
- AWS CLI v2, with credentials for an identity that can create IAM roles, VPCs and EKS clusters (for example AdministratorAccess)
- A MongoDB Atlas cluster (used by the application repo)

### 1. Configure

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Set github_owner to your GitHub user or organization.
# If the account already has the GitHub OIDC provider, set create_github_oidc_provider = false.
```

### 2. Apply

```bash
export AWS_REGION=us-east-1
./scripts/deploy-infrastructure.sh plan    # creates the state bucket, init, fmt, validate, plan
./scripts/deploy-infrastructure.sh apply   # plan + apply (takes about 15-20 minutes)
```

The script creates the state bucket `starttech-tfstate-<account>-<region>` (versioned, encrypted, private). State locking uses S3 native lock files, so no DynamoDB table is needed.

### 3. Connect GitHub

Get the values with `./scripts/deploy-infrastructure.sh output`.

**`starttech-infra` repository**

| Type | Name | Value |
|---|---|---|
| Secret | `AWS_ROLE_ARN` | `github_infra_role_arn` output |
| Variable | `AWS_REGION` | e.g. `us-east-1` |
| Variable (optional) | `TF_STATE_BUCKET` | only if you changed the default bucket name |
| Variable (optional) | `CREATE_GITHUB_OIDC_PROVIDER` | `false` if you set it to false locally |

Also create a GitHub environment named `production`. The OIDC trust policy allows it, and you can add required reviewers to gate `apply`.

The application repository's secrets and variables are listed in its README.

After this, every push to `main` that changes `terraform/` runs **fmt → init → validate → plan → `terraform apply -auto-approve`**. Pull requests run fmt and validate only, with no AWS credentials.

> CI sets `github_owner` to the repository owner. Use the same value locally to avoid plan drift.

### 4. MongoDB Atlas network access

The pods reach Atlas through the NAT gateway. Add the IPs from the `nat_gateway_public_ips` output to the Atlas IP Access List.

### 5. Grader credentials

```bash
./scripts/deploy-infrastructure.sh grader-credentials
```

This creates the console password and an access key for `start-tech-grader`, and prints them once. They are not stored in Terraform state. Running it again rotates them.

Check the read-only access:

```bash
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...
aws eks describe-cluster --name starttech-cluster --query cluster.version
aws eks describe-nodegroup --cluster-name starttech-cluster --nodegroup-name starttech-node-group --query nodegroup.instanceTypes
aws elasticache describe-cache-clusters --cache-cluster-id starttech-redis --query 'CacheClusters[0].CacheNodeType'
aws cloudfront list-distributions --query 'DistributionList.Items[].Origins.Items[].Id'
```

## Cost (us-east-1, approximate)

| Item | Monthly |
|---|---|
| EKS control plane | ~$73 |
| 2 × t3.medium nodes | ~$61 |
| NAT gateway (single) | ~$33 + data |
| ALB | ~$17 |
| ElastiCache cache.t3.micro | ~$12 |
| KMS, CloudWatch, S3, CloudFront, ECR | a few dollars |

That's roughly **$200/month**. Setting `single_nat_gateway = false` adds a NAT gateway per AZ for high availability.

## Teardown

```bash
./scripts/deploy-infrastructure.sh destroy
```

The bucket and ECR repository are created with `force_destroy`, so the destroy also removes their contents. The Terraform state bucket is kept; delete it by hand if you no longer need it.

## Design notes

- **Why Terraform owns the ALB.** If the AWS Load Balancer Controller created the ALB from the Ingress, its DNS name would only exist after the application deploys, and CloudFront would need a second apply. With Terraform owning the ALB and targeting a fixed NodePort, one apply wires everything together. The application repo still ships an `alb`-class Ingress with the same routing; it is used only if the controller is installed.
- **Error pages also apply to the API.** CloudFront custom error responses are distribution-wide, so a 403 or 404 from the API under `/api/*` is also turned into `index.html` with status 200. In this app that only affects edge cases: "todo not found" and "user not found". Validation errors (400), auth failures (401) and server errors pass through unchanged. If this matters later, replace the error responses with a CloudFront Function that rewrites SPA paths on the default behavior only.
- **Redis without TLS.** The Redis node sits in subnets without internet access and accepts connections only from the worker nodes. In-transit encryption can be turned on with `transit_encryption_enabled`, but the backend would then need TLS settings in its Redis client.
