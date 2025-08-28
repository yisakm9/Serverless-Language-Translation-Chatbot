# modules/lex_bot/outputs.tf
/*
output "bot_id" {
  description = "The unique ID of the Lex bot."
  value       = aws_lexv2models_bot.translation_bot.id
}

output "bot_alias_id" {
  description = "The unique ID of the bot alias."
  # Corrected: We now get this value by decoding the JSON output
  # from the aws_cloudcontrolapi_resource.
  value       = jsondecode(aws_cloudcontrolapi_resource.live.properties)["BotAliasId"]
}

output "bot_alias_arn" {
  description = "The ARN of the bot alias, which can be used as an endpoint."
  # This constructs the full ARN, which is often more useful than just the ID.
  value       = "arn:aws:lex:${var.aws_region}:${var.aws_account_id}:bot-alias/${aws_lexv2models_bot.translation_bot.id}/${jsondecode(aws_cloudcontrolapi_resource.live.properties)["BotAliasId"]}"
}*/