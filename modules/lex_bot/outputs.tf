# modules/lex_bot/outputs.tf

# Add these data sources to dynamically get the current region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


output "bot_id" {
  description = "The unique ID of the Lex bot."
  value       = aws_lexv2models_bot.translation_bot.id
}

output "bot_alias_id" {
  description = "The unique ID of the bot alias."
  value       = aws_lexv2models_bot_alias.live.bot_alias_id
}

output "bot_alias_name" {
  description = "The name of the bot alias."
  # Corrected: Referencing the new aws_lexv2models_bot_alias resource
  value       = aws_lexv2models_bot_alias.live.name
}

output "bot_alias_arn" {
  description = "The ARN of the bot alias."
  # Corrected: The aws_lexv2models_bot_alias resource does not provide a direct ARN.
  # We construct it using the standard format.
  value       = "arn:aws:lex:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:bot-alias/${aws_lexv2models_bot.translation_bot.id}/${aws_lexv2models_bot_alias.live.bot_alias_id}"
}