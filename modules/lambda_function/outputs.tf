# modules/lambda_function/outputs.tf

output "lambda_function_arn" {
  description = "The ARN of the created Lambda function."
  value       = aws_lambda_function.translator.arn
}