# modules/iam/variables.tf

variable "lambda_execution_role_name" {
  description = "The name for the Lambda function's execution role."
  type        = string
}