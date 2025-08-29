# environments/dev/outputs.tf
/*
output "lex_bot_id" {
  description = "The ID of the deployed Amazon Lex bot. Use this ID in the AWS Console to find your bot."
  value       = module.lex_bot.bot_id
}
*/

# Corrected: Changed to match the new output from the module
output "lex_bot_alias_name" {
  description = "The Alias Name for the 'live' version of the bot."
  value       = module.lex_bot.bot_alias_name
}

# Recommended: Also output the ARN, as it's very useful
output "lex_bot_alias_arn" {
  description = "The ARN for the 'live' alias of the bot."
  value       = module.lex_bot.bot_alias_arn
}

output "lambda_function_arn" {
  description = "The ARN of the backend Lambda function."
  value       = module.lambda_function.lambda_function_arn
}