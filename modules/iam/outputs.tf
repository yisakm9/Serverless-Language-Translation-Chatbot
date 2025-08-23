
output "lambda_execution_role_arn" {
  description = "The ARN of the Lambda execution role."
  value       = aws_iam_role.lambda_execution_role.arn
}