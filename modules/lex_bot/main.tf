# modules/lex_bot/main.tf

# 1. Create the main Lex Bot resource.
resource "aws_lexv2models_bot" "translation_bot" {
  name                        = var.bot_name
  data_privacy              { 
    child_directed = false 
    }
  idle_session_ttl_in_seconds = 300
  role_arn                    = "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/lexv2.amazonaws.com/AWSServiceRoleForLexV2Bots"
}

# 2. Define the bot's locale
resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id                           = aws_lexv2models_bot.translation_bot.id
  bot_version                      = "DRAFT"
  locale_id                        = "en_US"
  n_lu_intent_confidence_threshold = 0.40
  voice_settings { voice_id = "Matthew" }
}

# 3. Define the custom slot type for languages
resource "aws_lexv2models_slot_type" "language" {
  bot_id      = aws_lexv2models_bot.translation_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "Language"
  value_selection_setting { resolution_strategy = "TopResolution" }
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

# 4. Define the primary intent for translation
resource "aws_lexv2models_intent" "translate_text" {
  bot_id      = aws_lexv2models_bot.translation_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "TranslateText"

  sample_utterance {
    utterance = "Translate something"
  }

  sample_utterance {
    utterance = "Can you translate for me"
  }

  sample_utterance {
     utterance = "Translate to {targetLanguage}"
  }

  fulfillment_code_hook {
    enabled = true
  }
}

# 5. Define the slots for the 'TranslateText' intent
resource "aws_lexv2models_slot" "source_text" {
  name         = "sourceText"
  bot_id       = aws_lexv2models_bot.translation_bot.id
  bot_version  = "DRAFT"
  locale_id    = aws_lexv2models_bot_locale.en_us.locale_id
  intent_id    = aws_lexv2models_intent.translate_text.id
  slot_type_id = "AMAZON.FreeFormInput"
  value_elicitation_setting {
    slot_constraint = "Required"
    prompt_specification {
      max_retries = 2
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
  intent_id    = aws_lexv2models_intent.translate_text.id
  slot_type_id = aws_lexv2models_slot_type.language.id
  value_elicitation_setting {
    slot_constraint = "Required"
    prompt_specification {
      max_retries = 2
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

# 6. Define the mandatory Fallback Intent
resource "aws_lexv2models_intent" "fallback" {
  bot_id                  = aws_lexv2models_bot.translation_bot.id
  bot_version             = "DRAFT"
  locale_id               = aws_lexv2models_bot_locale.en_us.locale_id
  name                    = "FallbackIntent"
  parent_intent_signature = "AMAZON.FallbackIntent"
}

# 7. Grant Lex permission to invoke Lambda
resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "lexv2.amazonaws.com"
  source_arn    = "arn:aws:lex:${var.aws_region}:${var.aws_account_id}:bot-alias/${aws_lexv2models_bot.translation_bot.id}/*"
}

# 8. Create a version of the bot from the DRAFT
resource "aws_lexv2models_bot_version" "v1" {
  bot_id    = aws_lexv2models_bot.translation_bot.id
  locale_specification = {
    (aws_lexv2models_bot_locale.en_us.locale_id) = {
      source_bot_version = "DRAFT"
    }
  }
  # Ensure all intents are created before versioning
  depends_on = [aws_lexv2models_intent.translate_text, aws_lexv2models_intent.fallback]
}

# 9. Create a stable alias that points to our new version and connects the Lambda
resource "aws_lexv2models_bot_alias" "live" {
  bot_id         = aws_lexv2models_bot.translation_bot.id
  bot_alias_name = "live"
  bot_version    = aws_lexv2models_bot_version.v1.bot_version
  bot_alias_locale_settings {
    locale_id = aws_lexv2models_bot_locale.en_us.locale_id
    enabled   = true
    code_hook_specification {
      lambda_code_hook {
        lambda_arn                  = var.lambda_function_arn
        code_hook_interface_version = "1.0"
      }
    }
  }
}