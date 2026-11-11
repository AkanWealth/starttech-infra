#!/usr/bin/env bash
# Provisions the StartTech platform with Terraform.
#
# Usage: scripts/deploy-infrastructure.sh <command>
#
#   bootstrap           Create the S3 bucket for Terraform state
#   plan                bootstrap + init + fmt + validate + plan
#   apply               plan, then apply (default)
#   destroy             Destroy everything (asks for confirmation)
#   output              Show Terraform outputs
#   grader-credentials  Create the console password and access key for start-tech-grader
#
# Environment:
#   AWS_REGION       default us-east-1
#   TF_STATE_BUCKET  default starttech-tfstate-<account id>-<region>
#   AUTO_APPROVE     true to skip the apply/destroy confirmation

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"
COMMAND="${1:-apply}"

export AWS_REGION="${AWS_REGION:-us-east-1}"
export TF_VAR_aws_region="${TF_VAR_aws_region:-$AWS_REGION}"
GRADER_USER="start-tech-grader"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

require() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' is required but not installed"
  done
}

confirm() {
  [[ "${AUTO_APPROVE:-false}" == "true" ]] && return 0
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

account_id() { aws sts get-caller-identity --query Account --output text; }

state_bucket() {
  echo "${TF_STATE_BUCKET:-starttech-tfstate-$(account_id)-${AWS_REGION}}"
}

bootstrap() {
  local bucket
  bucket="$(state_bucket)"

  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    log "State bucket ${bucket} exists"
    return
  fi

  log "Creating state bucket ${bucket}"
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$bucket" >/dev/null
  else
    aws s3api create-bucket --bucket "$bucket" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION" >/dev/null
  fi
  aws s3api put-bucket-versioning --bucket "$bucket" \
    --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "$bucket" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  aws s3api put-public-access-block --bucket "$bucket" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
}

tf_init() {
  log "terraform init"
  terraform -chdir="$TF_DIR" init -input=false -reconfigure \
    -backend-config="bucket=$(state_bucket)" \
    -backend-config="region=${AWS_REGION}"
}

tf_checks() {
  log "terraform fmt"
  terraform -chdir="$TF_DIR" fmt -check -recursive || die "Run 'terraform fmt -recursive' in terraform/"
  log "terraform validate"
  terraform -chdir="$TF_DIR" validate
}

tf_plan() {
  [[ -f "${TF_DIR}/terraform.tfvars" ]] || warn "terraform/terraform.tfvars not found; using defaults (see terraform.tfvars.example)"
  log "terraform plan"
  terraform -chdir="$TF_DIR" plan -input=false -out=tfplan
}

tf_apply() {
  confirm "Apply the plan above?" || die "Aborted"
  log "terraform apply"
  terraform -chdir="$TF_DIR" apply -input=false -auto-approve tfplan
  rm -f "${TF_DIR}/tfplan"
  log "Done. Next steps:"
  terraform -chdir="$TF_DIR" output
}

tf_destroy() {
  warn "This deletes the cluster, database, bucket contents and all other resources."
  confirm "Destroy all StartTech infrastructure?" || die "Aborted"
  terraform -chdir="$TF_DIR" destroy -input=false -auto-approve
}

# Creates (or rotates) console and CLI credentials for the grader. The
# secrets are printed once and never stored in Terraform state.
grader_credentials() {
  aws iam get-user --user-name "$GRADER_USER" >/dev/null 2>&1 \
    || die "${GRADER_USER} does not exist. Run '$0 apply' first."

  local password
  require openssl
  password="$(openssl rand -hex 12)Aa1!"

  if aws iam get-login-profile --user-name "$GRADER_USER" >/dev/null 2>&1; then
    confirm "Reset the console password for ${GRADER_USER}?" || die "Aborted"
    aws iam update-login-profile --user-name "$GRADER_USER" \
      --password "$password" --no-password-reset-required
  else
    aws iam create-login-profile --user-name "$GRADER_USER" \
      --password "$password" --no-password-reset-required >/dev/null
  fi

  local existing
  existing="$(aws iam list-access-keys --user-name "$GRADER_USER" --query 'AccessKeyMetadata[].AccessKeyId' --output text)"
  if [[ -n "$existing" ]]; then
    confirm "Delete existing access key(s) ${existing} and create a new one?" || die "Aborted"
    for key in $existing; do
      aws iam delete-access-key --user-name "$GRADER_USER" --access-key-id "$key"
    done
  fi

  local access_key_id secret_access_key
  read -r access_key_id secret_access_key < <(aws iam create-access-key --user-name "$GRADER_USER" \
    --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)

  local acct
  acct="$(account_id)"
  cat <<INFO

=== start-tech-grader credentials (shown once; store them securely) ===
Console sign-in URL : https://${acct}.signin.aws.amazon.com/console
Account ID          : ${acct}
Username            : ${GRADER_USER}
Password            : ${password}
Access key ID       : ${access_key_id}
Secret access key   : ${secret_access_key}
Region              : ${AWS_REGION}
=======================================================================
INFO
}

require aws
case "$COMMAND" in
  bootstrap)          bootstrap ;;
  plan)               require terraform; bootstrap; tf_init; tf_checks; tf_plan ;;
  apply)              require terraform; bootstrap; tf_init; tf_checks; tf_plan; tf_apply ;;
  destroy)            require terraform; tf_init; tf_destroy ;;
  output)             require terraform; tf_init >/dev/null; terraform -chdir="$TF_DIR" output ;;
  grader-credentials) grader_credentials ;;
  *)                  sed -n '2,18p' "$0"; exit 1 ;;
esac
