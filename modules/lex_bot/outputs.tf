# modules/lex_bot/outputs.tf

output "bot_name" {
  description = "The name of the Lex V1 bot."
  # Lex V1 bots use 'name' as their primary identifier, not a separate 'id'.
  value       = aws_lex_bot.translation_bot.name
}

output "bot_alias_name" {
  description = "The name of the bot alias."
  # This correctly references the aws_lex_bot_alias resource.
  value       = aws_lex_bot_alias.live.name
}

output "bot_alias_arn" {
  description = "The ARN of the bot alias."
  # This correctly references the aws_lex_bot_alias resource.
  value       = aws_lex_bot_alias.live.arn
}