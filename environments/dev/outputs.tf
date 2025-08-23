# environments/dev/outputs.tf

output "lex_bot_id" {
  description = "The ID of the deployed Amazon Lex bot. Use this ID in the AWS Console to find your bot."
  value       = module.lex_bot.bot_id
}

output "lex_bot_alias_id" {
  description = "The Alias ID for the 'live' version of the bot."
  value       = module.lex_bot.bot_alias_id
}

output "lambda_function_arn" {
  description = "The ARN of the backend Lambda function."
  value       = module.lambda_function.lambda_function_arn
}