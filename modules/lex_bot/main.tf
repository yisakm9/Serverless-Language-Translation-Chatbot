# 1. Create the Lex Bot using the awscc provider
resource "awscc_lex_bot" "translation_bot" {
  name                         = var.bot_name
  data_privacy                 = { child_directed = false }
  idle_session_ttl_in_seconds  = 300
  role_arn                     = "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/lexv2.amazonaws.com/AWSServiceRoleForLexV2Bots"

  # The awscc provider requires defining at least one locale at creation time
  bot_locales = [{
    locale_id                         = "en_US"
    nlu_confidence_threshold          = 0.40
    voice_settings                    = { voice_id = "Matthew" }

    # Define intents and slots directly inside the locale
    intents = [{
      name        = "TranslateText"
      description = "Intent to translate text"
      sample_utterances = [
        { utterance = "Translate {sourceText} to {targetLanguage}" },
        { utterance = "How do you say {sourceText} in {targetLanguage}" }
      ]
      
      # Define slots for this intent
      slots = [
        {
          name         = "sourceText"
          slot_type_name = "AMAZON.FreeFormInput"
          value_elicitation_setting = {
            slot_constraint = "Required"
            prompt_specification = {
              max_retries = 2
              message_groups_list = [{
                message = {
                  plain_text_message = {
                    value = "What text would you like to translate?"
                  }
                }
              }]
            }
          }
        },
        {
          name         = "targetLanguage"
          slot_type_name = "Language" # Reference our custom slot type name
           value_elicitation_setting = {
            slot_constraint = "Required"
            prompt_specification = {
              max_retries = 2
              message_groups_list = [{
                message = {
                  plain_text_message = {
                    value = "Which language should I translate it to?"
                  }
                }
              }]
            }
          }
        }
      ] # end slots

      # Connect the intent to the Lambda function
      fulfillment_code_hook = {
        enabled = true
      }
    }] # end intents

    # Define custom slot types for this locale
    slot_types = [{
      name = "Language"
      description = "Languages for translation"
      value_selection_setting = {
        resolution_strategy = "TOP_RESOLUTION"
      }
      slot_type_values = [
        { sample_value = { value = "Spanish" } },
        { sample_value = { value = "French" } },
        { sample_value = { value = "German" } },
      ]
    }] # end slot_types
  }] # end bot_locales
}

# 2. Grant Lex permission to invoke Lambda (using the standard 'aws' provider)
resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "lexv2.amazonaws.com"
  # awscc resources use .arn instead of .id for the ARN
  source_arn    = "${awscc_lex_bot.translation_bot.arn}-alias/*" 
}

# 3. Create a version of the bot from the DRAFT
resource "awscc_lex_bot_version" "v1" {
  bot_id      = awscc_lex_bot.translation_bot.id
  bot_version_locale_specification = [{
    locale_id = "en_US"
    bot_version_locale_details = {
      source_bot_version = "DRAFT"
    }
  }]
}

# 4. Create a stable alias pointing to the new version
resource "awscc_lex_bot_alias" "live" {
  bot_id         = awscc_lex_bot.translation_bot.id
  bot_alias_name = "live"
  bot_version    = awscc_lex_bot_version.v1.bot_version

  bot_alias_locale_settings = [{
    locale_id = "en_US"
    enabled   = true
    bot_alias_locale_setting = {
      code_hook_specification = {
        lambda_code_hook = {
          code_hook_interface_version = "1.0"
          lambda_arn                  = var.lambda_function_arn
        }
      }
    }
  }]
}