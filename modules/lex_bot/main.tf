# Add this resource to ensure the Lex Service-Linked Role exists
resource "aws_iam_service_linked_role" "lexv2" {
  aws_service_name = "lexv2.amazonaws.com"
}

# Corrected: Renamed to aws_lexv2models_bot
resource "aws_lexv2models_bot" "translation_bot" {
  name                        = var.bot_name
  data_privacy              {
    child_directed = false
  }
  idle_session_ttl_in_seconds = 300
  role_arn = aws_iam_service_linked_role.lexv2.arn

}

# 2. Define the bot's locale
# Corrected: Renamed to aws_lexv2models_bot_locale
resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id                           = aws_lexv2models_bot.translation_bot.id
  bot_version                      = "DRAFT"
  locale_id                        = "en_US"
  n_lu_intent_confidence_threshold  = 0.40
  voice_settings { voice_id = "Matthew" }
}

# 3. Define the custom slot type for languages
# Corrected: Renamed to aws_lexv2models_slot_type
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
# Corrected: Renamed to aws_lexv2models_intent
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

  # Added: Explicit dependency on the slots it uses
  # depends_on = [
  #  aws_lexv2models_slot.source_text,
  #  aws_lexv2models_slot.target_language
  #]
}

# 5. Define the slots for the 'TranslateText' intent
# Corrected: Added explicit values for allow_interrupt and message_selection_strategy
resource "aws_lexv2models_slot" "source_text" {
  name         = "sourceText"
  bot_id       = aws_lexv2models_bot.translation_bot.id
  bot_version  = "DRAFT"
  locale_id    = aws_lexv2models_bot_locale.en_us.locale_id
  intent_id    = aws_lexv2models_intent.translate_text.intent_id
  slot_type_id = "AMAZON.FreeFormInput"
  value_elicitation_setting {
    slot_constraint = "Required"
    prompt_specification {
      max_retries = 2
      
      # Add these two lines to match AWS API defaults
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
# Corrected: Renamed to aws_lexv2models_slot
# Corrected: Added explicit values for allow_interrupt and message_selection_strategy
resource "aws_lexv2models_slot" "target_language" {
  name         = "targetLanguage"
  bot_id       = aws_lexv2models_bot.translation_bot.id
  bot_version  = "DRAFT"
  locale_id    = aws_lexv2models_bot_locale.en_us.locale_id
  intent_id    = aws_lexv2models_intent.translate_text.intent_id
  slot_type_id = aws_lexv2models_slot_type.language.slot_type_id
  value_elicitation_setting {
    slot_constraint = "Required"
    prompt_specification {
      max_retries = 2

      # Add these two lines to match AWS API defaults
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


# 7. Grant Lex permission to invoke Lambda
resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "lexv2.amazonaws.com" # Corrected: Use V2 principal
  source_arn    = aws_lex_bot_alias.live.arn # Corrected: Source from V2 alias
}

# 8. Create a version of the bot from the DRAFT
# Corrected: Renamed to aws_lexv2models_bot_version
resource "aws_lexv2models_bot_version" "v1" {
  bot_id    = aws_lexv2models_bot.translation_bot.id
  locale_specification = {
    (aws_lexv2models_bot_locale.en_us.locale_id) = {
      source_bot_version = "DRAFT"
    }
  }
  # Ensure all intents and slots are created before versioning
  depends_on = [
    aws_lexv2models_intent.translate_text,
    aws_lexv2models_slot.source_text,
    aws_lexv2models_slot.target_language
  ]
}

# 9. Create a stable alias that points to our new version and connects the Lambda
# Corrected: Renamed to aws_lex_bot_alias
resource "aws_lex_bot_alias" "live" {
  bot_name = aws_lexv2models_bot.translation_bot.name # Use the bot name here
  name     = "live"                                   # Alias name
  bot_version = aws_lexv2models_bot_version.v1.bot_version
# ADD THIS BLOCK to explicitly tell the alias to wait for the roles.
      depends_on = [   aws_iam_service_linked_role.lexv2        ]

  conversation_logs {
    
    iam_role_arn = aws_iam_service_linked_role.lexv2.arn
    log_settings {
      destination = "CLOUDWATCH_LOGS"
      log_type    = "TEXT"
      resource_arn = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lex/${var.bot_name}" # Example log group, adjust as needed
    }
  }
  
  # The Lambda integration is configured differently in this resource
  # It's often handled at the intent level or through conversation logs
}
resource "aws_lexv2models_bot_alias" "example_alias" {
  bot_alias_name = "MyBotAlias"
  bot_id         = "YOUR_BOT_ID"
  bot_version    = "DRAFT"
  description    = "My bot alias description"

  sentiment_analysis_settings {
    detect_sentiment = false
  }

  conversation_log_settings {
    audio_log_settings {
      destination {
        s3_bucket = "your-s3-bucket-name"
      }
      enabled = true
    }
    text_log_settings {
      destination {
        cloudwatch_log_group = "my-lex-log-group"
      }
      enabled = true
    }
  }
}
