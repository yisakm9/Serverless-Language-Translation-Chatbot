# modules/lex_bot/outputs.tf

output "bot_id" {
  description = "The unique ID of the Lex bot."
  value       = aws_lexv2models_bot.translation_bot.id
}
/*
output "bot_alias_name" {
  description = "The name of the bot alias."
  # Corrected: Referencing the aws_lex_bot_alias resource we fixed earlier.
  # This resource uses "name" as its primary identifier.
  value       = aws_lex_bot_alias.live.name
}

output "bot_alias_arn" {
  description = "The ARN of the bot alias."
  # Corrected: The aws_lex_bot_alias resource directly provides the ARN as an attribute.
  value       = aws_lex_bot_alias.live.arn
}
*/