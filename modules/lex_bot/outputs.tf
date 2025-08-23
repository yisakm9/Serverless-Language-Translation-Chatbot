# modules/lex_bot/outputs.tf

output "bot_id" {
  description = "The unique ID of the Lex bot."
  value       = awscc_lex_bot.translation_bot.id
}

output "bot_alias_id" {
  description = "The unique ID of the bot alias."
  value       = awscc_lex_bot_alias.live.id
}