# starttech-infra

Terraform for the StartTech platform on AWS: VPC, EKS, S3, CloudFront, ECR and ElastiCache Redis.

```text
Browser --HTTPS--> CloudFront --+-- *      --> S3-Frontend (private bucket, OAC)
                                +-- /api/* --> ALB-Backend --> EKS NodePort 30080 --> backend-api :8080
                                                                    |
                                                                    +--> ElastiCache starttech-redis
```

## Modules

| Module        | Creates                                                                          |
| ------------- | -------------------------------------------------------------------------------- |
| `networking/` | `starttech-vpc` (10.0.0.0/16), 2 public, 2 private and 2 database subnets, IGW, NAT |
| `eks/`        | `starttech-cluster`, `starttech-node-group` (2 × t3.small), IAM roles, backend ALB |
| `storage/`    | Private `starttech-frontend-bucket-<account id>`, ECR `starttech-backend-api`      |
| `cdn/`        | One CloudFront distribution with origins `S3-Frontend` (OAC) and `ALB-Backend`     |
| `database/`   | `starttech-redis` (cache.t3.micro, 1 node), reachable only from the EKS nodes      |

The `start-tech-grader` IAM user and its read-only policy are in `terraform/main.tf`.

CloudFront details:

- Default behavior (`*`) serves S3-Frontend and redirects HTTP to HTTPS.
- The `/api/*` behavior goes to ALB-Backend with `min_ttl`, `default_ttl` and `max_ttl` set to 0, forwarding all headers, cookies and query strings.
- 403 and 404 errors return `/index.html` with status 200, so React client-side routes survive a refresh.

## Deploy

The first apply runs locally. It creates the Terraform state bucket, then applies:

```bash
export AWS_REGION=us-east-1
./scripts/deploy-infrastructure.sh
```

After that, every push to `main` that changes `terraform/` runs `terraform fmt`, `terraform validate` and `terraform apply -auto-approve`.

GitHub configuration for this repository:

| Kind     | Name                    | Value                                     |
| -------- | ----------------------- | ----------------------------------------- |
| Secret   | `AWS_ACCESS_KEY_ID`     | Access key of the deploying IAM user      |
| Secret   | `AWS_SECRET_ACCESS_KEY` | Secret key of the deploying IAM user      |
| Variable | `AWS_REGION`            | e.g. `us-east-1`                          |
| Variable | `TF_STATE_BUCKET`       | `starttech-tfstate-<account id>`          |

## After the first apply

- Add the `nat_gateway_public_ip` output to the MongoDB Atlas IP access list.
- In the IAM console, create a console password and an access key for `start-tech-grader`.
