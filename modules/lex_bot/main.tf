# Add this resource to ensure the Lex Service-Linked Role exists
resource "aws_iam_service_linked_role" "lexv2" {
  aws_service_name = "lexv2.amazonaws.com"
}

# This service-linked role is for Lex V1 and might not be implicitly required
# if you are exclusively using Lex V2 resources. However, if any part of your
# infrastructure still uses Lex V1, it's good to have.
resource "aws_iam_service_linked_role" "lex" {
  aws_service_name = "lex.amazonaws.com"
}

# IAM Role for the Lex Bot to execute and call other services (like Lambda)
resource "aws_iam_role" "lex_bot_role" {
  name = "${var.bot_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lexv2.amazonaws.com"
        }
      },
    ]
  })
}

# It's a good practice to attach necessary policies to the role.
# For now, we are creating the role. You would add policies for Lambda invocation, etc.

# Corrected: Renamed to aws_lexv2models_bot
resource "aws_lexv2models_bot" "translation_bot" {
  name = var.bot_name
  data_privacy {
    child_directed = false
  }
  idle_session_ttl_in_seconds = 300
  role_arn                      = aws_iam_role.lex_bot_role.arn
}

# 2. Define the bot's locale
# Corrected: Renamed to aws_lexv2models_bot_locale
resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id      = aws_lexv2models_bot.translation_bot.id
  bot_version = "DRAFT"
  locale_id   = "en_US"
  n_lu_intent_confidence_threshold = 0.40
  voice_settings {
    voice_id = "Matthew"
  }
}

# 3. Define the custom slot type for languages
# Corrected: Renamed to aws_lexv2models_slot_type
resource "aws_lexv2models_slot_type" "language" {
  bot_id      = aws_lexv2models_bot.translation_bot.id
  bot_version = "DRAFT"
  locale_id   = aws_lexv2models_bot_locale.en_us.locale_id
  name        = "Language"
  value_selection_setting {
    resolution_strategy = "TopResolution"
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
  depends_on = [
    aws_lexv2models_slot.source_text,
    aws_lexv2models_slot.target_language
  ]
}

# 5. Define the slots for the 'TranslateText' intent
resource "aws_lexv2models_slot" "source_text" {
  name         = "sourceText"
  bot_id       = aws_lexv2models_bot.translation_bot.id
  bot_version  = "DRAFT"
  locale_id    = aws_lexv2models_bot_locale.en_us.locale_id
  intent_id    = aws_lexv2models_intent.translate_text.id # Corrected to use the intent's ID
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
  intent_id    = aws_lexv2models_intent.translate_text.id # Corrected to use the intent's ID
  slot_type_id = aws_lexv2models_slot_type.language.id    # Corrected to use the slot type's ID
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
  bot_id = aws_lexv2models_bot.translation_bot.id
  locale_specification = {
    (aws_lexv2models_bot_locale.en_us.locale_id) = {
      source_bot_version = "DRAFT"
    }
  }
  # Ensure all intents and slots are created before versioning
  depends_on = [
    aws_lexv2models_intent.translate_text,
  ]
}

# 9. Create a stable alias that points to our new version and connects the Lambda
# Corrected: Using the appropriate Lex V2 alias resource
resource "aws_lexv2models_bot_alias" "live" {
  name          = "live"
  bot_id        = aws_lexv2models_bot.translation_bot.id
  bot_version   = aws_lexv2models_bot_version.v1.bot_version

  bot_alias_locale_settings {
    locale_id = "en_US"
    enabled   = true
    code_hook_specification {
      lambda_code_hook {
        code_hook_interface_version = "1.0"
        lambda_arn                  = var.lambda_function_arn
      }
    }
  }

  conversation_log_settings {
    cloudwatch_log_group_settings {
      cloudwatch_log_group_arn = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lex/${var.bot_name}"
    }
    iam_role_arn = aws_iam_role.lex_bot_role.arn # Use the bot's role for logging
  }

  depends_on = [
    aws_iam_service_linked_role.lex,
    aws_iam_service_linked_role.lexv2
  ]
}

# 7. Grant Lex permission to invoke Lambda
# Corrected: Updated principal and source_arn
resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "lexv2.amazonaws.com"
  source_arn    = "arn:aws:lex:${var.aws_region}:${var.aws_account_id}:bot-alias/${aws_lexv2models_bot.translation_bot.id}/${aws_lexv2models_bot_alias.live.id}"
}