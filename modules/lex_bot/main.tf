# modules/lex_bot/main.tf

# 1. Create the main Lex Bot resource.
# Lex will automatically create a service-linked IAM role for this.
resource "aws_lexv2_bot" "translation_bot" {
  name                              = var.bot_name
  data_privacy {
    child_directed = false
  }
  idle_session_ttl_in_seconds       = 300
  role_arn                          = "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/lexv2.amazonaws.com/AWSServiceRoleForLexV2Bots"
  
  
}

# 2. Define a custom slot type for target languages
resource "aws_lexv2_slot_type" "language" {
  bot_id                = aws_lexv2_bot.translation_bot.id
  bot_version           = "DRAFT" # Custom types are added to the draft version
  locale_id             = "en_US"
  name                  = "Language"
  value_selection_setting {
    resolution_strategy = "TOP_RESOLUTION"
  }
  slot_type_values {
    sample_value {
      value = "Spanish"
    }
  }
  slot_type_values {
    sample_value {
      value = "French"
    }
  }
  slot_type_values {
    sample_value {
      value = "German"
    }
  }
}

# 3. Define the primary intent for translation
resource "aws_lexv2_intent" "translate_text" {
  bot_id      = aws_lexv2_bot.translation_bot.id
  bot_version = "DRAFT" # Intents are added to the draft version
  locale_id   = "en_US"
  name        = "TranslateText"

  sample_utterance {
    utterance = "Translate {sourceText} to {targetLanguage}"
  }
  sample_utterance {
    utterance = "How do you say {sourceText} in {targetLanguage}"
  }
  sample_utterance {
    utterance = "In {targetLanguage} what is {sourceText}"
  }

  # Define the slot for the text to be translated
  slot {
    name        = "sourceText"
    slot_type_id = "AMAZON.FreeFormInput" # A built-in type for open-ended text
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

  # Define the slot for the target language
  slot {
    name         = "targetLanguage"
    slot_type_id = aws_lexv2_slot_type.language.id # Use our custom slot type
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

  # 4. Configure the intent to use our Lambda function for fulfillment
  fulfillment_code_hook {
    enabled = true
  }
}

# 5. Grant the Lex bot permission to invoke the Lambda function
resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "lexv2.amazonaws.com"
  source_arn = "arn:aws:lex:${var.aws_region}:${var.aws_account_id}:bot-alias/${aws_lexv2_bot.translation_bot.id}/*"

}

# 6. Define the bot's locale (language) and link the intent to it
resource "aws_lexv2_bot_locale" "en_us" {
  bot_id      = aws_lexv2_bot.translation_bot.id
  bot_version = "DRAFT" # This configures the draft version
  locale_id   = "en_US"
  n_lu_intent_confidence_threshold = 0.40
  voice_settings {
    voice_id = "Matthew"
    engine   = "neural"
  }
  depends_on = [ aws_lexv2_intent.translate_text ]
}

# 7. Create a version of the bot from the DRAFT. This is like "publishing".
resource "aws_lexv2_bot_version" "v1" {
  bot_id    = aws_lexv2_bot.translation_bot.id
  locale_specification = {
    "en_US" = {
      source_bot_version = "DRAFT"
    }
  }
  depends_on = [ aws_lexv2_bot_locale.en_us ]
}

# 8. Create a stable alias that points to our new version. This is the endpoint.
resource "aws_lexv2_bot_alias" "live" {
  bot_id          = aws_lexv2_bot.translation_bot.id
  bot_alias_name  = "live"
  bot_version     = aws_lexv2_bot_version.v1.bot_version

  bot_alias_locale_settings {
    locale_id = "en_US"
    enabled   = true
    code_hook_specification {
      lambda_arn {
        lambda_arn = var.lambda_function_arn
        code_hook_interface_version = "1.0"
      }
    }
  }
}