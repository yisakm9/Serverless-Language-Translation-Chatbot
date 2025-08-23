
variable "function_name" {
  description = "The name of the Lambda function."
  type        = string
}

variable "iam_role_arn" {
  description = "The ARN of the IAM role for the Lambda function."
  type        = string
}

variable "source_code_path" {
  description = "The path to the Lambda function's source code file."
  type        = string
}

variable "handler" {
  description = "The function entrypoint in your code."
  type        = string
  default     = "index.lambda_handler"
}

variable "runtime" {
  description = "The runtime environment for the Lambda function."
  type        = string
  default     = "python3.9"
}