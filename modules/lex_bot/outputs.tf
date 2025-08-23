# modules/lex_bot/outputs.tf

output "bot_id" {
  description = "The unique ID of the Lex bot."
  value       = aws_lexv2models_bot.translation_bot.id
}

output "bot_alias_id" {
  description = "The unique ID of the bot alias."
  value       = aws_lexv2models_bot_alias.live.bot_alias_id
}