output "github_infra_role_arn" {
  description = "Role ARN for the starttech-infra workflow (secret AWS_ROLE_ARN)."
  value       = try(aws_iam_role.github_infra[0].arn, null)
}

output "github_app_role_arn" {
  description = "Role ARN for the starttech-application workflows (secret AWS_ROLE_ARN)."
  value       = try(aws_iam_role.github_app[0].arn, null)
}

output "grader_user_name" {
  description = "Name of the read-only grader IAM user."
  value       = try(aws_iam_user.grader[0].name, null)
}

output "grader_user_arn" {
  description = "ARN of the read-only grader IAM user."
  value       = try(aws_iam_user.grader[0].arn, null)
}
