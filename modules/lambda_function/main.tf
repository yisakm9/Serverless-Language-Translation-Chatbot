# modules/lambda_function/main.tf

# 1. Package the source code into a .zip file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = var.source_code_path
  output_path = "${path.module}/lambda_function.zip" # A temporary path for the zip file
}

# 2. Create the AWS Lambda function resource
resource "aws_lambda_function" "translator" {
  function_name = var.function_name
  role          = var.iam_role_arn # This connects the Lambda to the IAM role from the other module

  # Deployment package settings
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Function settings
  handler = var.handler
  runtime = var.runtime
  timeout = 10 # Seconds
}