#!/usr/bin/env bash
# Provisions the StartTech infrastructure with Terraform.
#
# Usage: scripts/deploy-infrastructure.sh
# Env:   AWS_REGION (default us-east-1), TF_STATE_BUCKET (default starttech-tfstate-<account id>)
set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
export AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-starttech-tfstate-${ACCOUNT_ID}}"

# Create the Terraform state bucket on the first run.
if ! aws s3api head-bucket --bucket "$TF_STATE_BUCKET" 2>/dev/null; then
  echo "Creating state bucket ${TF_STATE_BUCKET}"
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$TF_STATE_BUCKET"
  else
    aws s3api create-bucket --bucket "$TF_STATE_BUCKET" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
fi

cd "$TF_DIR"
terraform init -backend-config="bucket=${TF_STATE_BUCKET}" -backend-config="region=${AWS_REGION}"
terraform fmt -check -recursive
terraform validate
terraform apply -auto-approve -var="aws_region=${AWS_REGION}"
terraform output
