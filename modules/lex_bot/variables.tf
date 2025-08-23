
variable "bot_name" {
  description = "The name for the Amazon Lex bot."
  type        = string
}

variable "lambda_function_arn" {
  description = "The ARN of the Lambda function for fulfillment."
  type        = string
}

variable "aws_region" {
  description = "The AWS region where the resources are created."
  type        = string
}

variable "aws_account_id" {
  description = "The AWS account ID."
  type        = string
}