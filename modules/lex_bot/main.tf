

# 1. IAM Service-Linked Role for LexV2
resource "aws_iam_service_linked_role" "lexv2" {
  aws_service_name = "lexv2.amazonaws.com"
}

# 2. IAM Role for the Lex Bot to execute and call other services
resource "aws_iam_role" "lex_bot_role" {
  name = "${var.bot_name}-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lexv2.amazonaws.com" }
    }]
  })
}

# 3. Define the Lex V2 Bot
resource "aws_lexv2models_bot" "translation_bot" {
  name                        = var.bot_name
  idle_session_ttl_in_seconds = 300
  role_arn                    = aws_iam_role.lex_bot_role.arn

  data_privacy {
    child_directed = false
  }

  depends_on = [aws_iam_service_linked_role.lexv2]
}

# 4. Define the bot's locale
resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id      = aws_lexv2models_bot.translation_bot.id
  bot_version = "DRAFT"
  locale_id   = "en_US"
  n_lu_intent_confidence_threshold = 0.40
  voice_settings {
    voice_id = "Matthew"
  }
}

# 5. Define the custom slot type for languages
resource "aws_lexv2models_slot_type" "language" {
  bot_id      = aws_lexv2models_bot.translation_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "Language"
  value_selection_setting {
    resolution_strategy = "TopResolution"
  }
  slot_type_values {
    sample_value { value = "Spanish" }
  }
  slot_type_values {
    sample_value { value = "French" }
  }
  slot_type_values {
    sample_value { value = "German" }
  }
}

# 6. Define the primary intent for translation
resource "aws_lexv2models_intent" "translate_text" {
  bot_id      = aws_lexv2models_bot.translation_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "TranslateText"

  sample_utterance { utterance = "Translate something" }
  sample_utterance { utterance = "Can you translate for me" }
  sample_utterance { utterance = "Translate to {targetLanguage}" }

  fulfillment_code_hook {
    enabled = true
  }
}

# 7. Define the slots for the 'TranslateText' intent
resource "aws_lexv2models_slot" "source_text" {
  name         = "sourceText"
  bot_id       = aws_lexv2models_bot.translation_bot.id
  bot_version  = "DRAFT"
  locale_id    = aws_lexv2models_bot_locale.en_us.locale_id
  intent_id    = aws_lexv2models_intent.translate_text.id # Correctly use ID
  slot_type_id = "AMAZON.FreeFormInput"

  value_elicitation_setting {
    slot_constraint = "Required"
    prompt_specification {
      max_retries                = 2
      allow_interrupt            = true
      message_selection_strategy = "Random"
      message_group {
        message {
          plain_text_message {
            value = "What text would you like to translate?"
          }
        }
      }
    }
  }
}

resource "aws_lexv2models_slot" "target_language" {
  name         = "targetLanguage"
  bot_id       = aws_lexv2models_bot.translation_bot.id
  bot_version  = "DRAFT"
  locale_id    = aws_lexv2models_bot_locale.en_us.locale_id
  intent_id    = aws_lexv2models_intent.translate_text.id # Correctly use ID
  slot_type_id = aws_lexv2models_slot_type.language.id   # Correctly use ID

  value_elicitation_setting {
    slot_constraint = "Required"
    prompt_specification {
      max_retries                = 2
      allow_interrupt            = true
      message_selection_strategy = "Random"
      message_group {
        message {
          plain_text_message {
            value = "Which language should I translate it to?"
          }
        }
      }
    }
  }
}

# 8. Create a version of the bot from the DRAFT
resource "aws_lexv2models_bot_version" "v1" {
  bot_id  = aws_lexv2models_bot.translation_bot.id
  locale_specification = {
    (aws_lexv2models_bot_locale.en_us.locale_id) = {
      source_bot_version = "DRAFT"
    }
  }
  depends_on = [
    aws_lexv2models_intent.translate_text,
    aws_lexv2models_slot.source_text,
    aws_lexv2models_slot.target_language
  ]
}

# 9. Create a stable alias that points to our new version
# THIS IS THE CORRECT V2 ALIAS RESOURCE
resource "aws_lexv2models_bot_alias" "live" {
  name        = "live"
  bot_id      = aws_lexv2models_bot.translation_bot.id
  bot_version = aws_lexv2models_bot_version.v1.bot_version

  bot_alias_locale_settings {
    enabled   = true
    locale_id = aws_lexv2models_bot_locale.en_us.locale_id
    code_hook_specification {
      lambda_code_hook {
        code_hook_interface_version = "1.0"
        lambda_arn                  = var.lambda_function_arn
      }
    }
  }
}

# 10. Grant Lex permission to invoke Lambda
resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "lexv2.amazonaws.com"
  source_arn    = aws_lexv2models_bot_alias.live.arn
}