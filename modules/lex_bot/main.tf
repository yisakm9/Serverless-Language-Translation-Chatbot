# Corrected: Renamed to aws_lexv2models_bot
resource "aws_lexv2models_bot" "translation_bot" {
  name           = var.bot_name
  data_privacy {
    child_directed = false
  }
  idle_session_ttl_in_seconds = 300
  role_arn                    = "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/lex.amazonaws.com/AWSServiceRoleForLexBots"
}

# 2. Define the bot's locale
# Corrected: Renamed to aws_lexv2models_bot_locale
resource "aws_lexv2models_bot_locale" "en_us" {
  bot_id                           = aws_lexv2models_bot.translation_bot.id
  bot_version                      = "DRAFT"
  locale_id                        = "en_US"
  n_lu_intent_confidence_threshold = 0.40
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
}

# 5. Define the slots for the 'TranslateText' intent
# Corrected: Renamed to aws_lexv2models_slot
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
# Corrected: Renamed to aws_lexv2models_intent
resource "aws_lexv2models_intent" "fallback" {
  bot_id                  = aws_lexv2models_bot.translation_bot.id
  bot_version             = "DRAFT"
  locale_id               = aws_lexv2models_bot_locale.en_us.locale_id
  name                    = "FallbackIntent"
  parent_intent_signature = "AMAZON.FallbackIntent"
}

# ==============================================================================
# CHANGE START
# ==============================================================================

# 7. Grant Lex permission to invoke Lambda
resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "lex.amazonaws.com"

  # Corrected: The source_arn now references the output of the aws_cloudcontrolapi_resource
  # which correctly manages the bot alias.
  source_arn    = "arn:aws:lex:${var.aws_region}:${var.aws_account_id}:bot-alias/${aws_lexv2models_bot.translation_bot.id}/${jsondecode(aws_cloudcontrolapi_resource.live.properties)["BotAliasId"]}"

  # Explicitly depend on the alias resource to ensure it's created first.
  depends_on = [aws_cloudcontrolapi_resource.live]
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
    aws_lexv2models_intent.fallback,
    aws_lexv2models_slot.source_text,
    aws_lexv2models_slot.target_language
  ]
}

# 9. Create a stable alias using the AWS Cloud Control API provider
# This is the modern, state-managed workaround for the missing dedicated resource.
resource "aws_cloudcontrolapi_resource" "live" {
  # This is the standardized CloudFormation/CloudControl type name for a Lex V2 Bot Alias.
  type_name = "AWS::Lex::BotAlias"

  # The desired_state is a JSON object that defines the alias configuration.
  desired_state = jsonencode({
    BotAliasName = "live"
    BotId        = aws_lexv2models_bot.translation_bot.id
    BotVersion   = aws_lexv2models_bot_version.v1.bot_version
    BotAliasLocaleSettings = [
      {
        BotAliasLocaleSetting = {
          Enabled = true
          CodeHookSpecification = {
            LambdaCodeHook = {
              CodeHookInterfaceVersion = "1.0"
              LambdaArn                = var.lambda_function_arn
            }
          }
        }
        LocaleId = aws_lexv2models_bot_locale.en_us.locale_id
      }
    ]
  })
}

