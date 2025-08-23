# modules/lex_bot/main.tf

# 1. Create the Lex Bot using the awscc provider
resource "awscc_lex_bot" "translation_bot" {
  name                         = var.bot_name
  data_privacy                 = { child_directed = false }
  idle_session_ttl_in_seconds  = 300
  role_arn                     = "arn:aws:iam::${var.aws_account_id}:role/aws-service-role/lexv2.amazonaws.com/AWSServiceRoleForLexV2Bots"

  bot_locales = [{
    locale_id                         = "en_US"
    nlu_confidence_threshold          = 0.40
    voice_settings                    = { voice_id = "Matthew" }

    intents = [
      # This is our primary, custom intent
      {
        name        = "TranslateText"
        description = "Intent to translate text"
        sample_utterances = [
          { utterance = "Translate {sourceText} to {targetLanguage}" },
          { utterance = "How do you say {sourceText} in {targetLanguage}" }
        ]
        slots = [
          {
            name         = "sourceText"
            slot_type_name = "AMAZON.FreeFormInput"
            value_elicitation_setting = {
              slot_constraint = "Required"
              prompt_specification = {
                max_retries = 2
                message_groups_list = [{
                  message = { plain_text_message = { value = "What text would you like to translate?" } }
                }]
              }
            }
          },
          {
            name         = "targetLanguage"
            slot_type_name = "Language"
            value_elicitation_setting = {
              slot_constraint = "Required"
              prompt_specification = {
                max_retries = 2
                message_groups_list = [{
                  message = { plain_text_message = { value = "Which language should I translate it to?" } }
                }]
              }
            }
          }
        ]
        fulfillment_code_hook = { enabled = true }
      },
      
      # --- ADDED: The required Fallback Intent ---
      # This tells Lex what to do when it doesn't understand the user.
      {
        name = "FallbackIntent"
        # This special signature tells Lex to use the built-in fallback behavior.
        parent_intent_signature = "AMAZON.FallbackIntent"
        # We will provide a simple closing message directly from Lex.
        intent_closing_setting = {
          closing_response = {
            message_groups_list = [{
              message = { plain_text_message = { value = "Sorry, I didn't understand. You can ask me to translate something, for example: 'Translate hello to Spanish'." } }
            }]
          }
        }
      }
      # --- END of added block ---
    ] # end intents

    slot_types = [{
      name = "Language"
      description = "Languages for translation"
      value_selection_setting = { resolution_strategy = "TOP_RESOLUTION" }
      slot_type_values = [
        { sample_value = { value = "Spanish" } },
        { sample_value = { value = "French" } },
        { sample_value = { value = "German" } },
      ]
    }]
  }]
}

# 2. Grant Lex permission to invoke Lambda
resource "aws_lambda_permission" "lex_invoke" {
  statement_id  = "AllowLexToInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "lexv2.amazonaws.com"
  source_arn    = "${awscc_lex_bot.translation_bot.arn}-alias/*" 
}

# 3. Create a version of the bot from the DRAFT
resource "awscc_lex_bot_version" "v1" {
  bot_id      = awscc_lex_bot.translation_bot.id
  bot_version_locale_specification = [{
    locale_id = "en_US"
    bot_version_locale_details = { source_bot_version = "DRAFT" }
  }]
}

# 4. Create a stable alias pointing to the new version
resource "awscc_lex_bot_alias" "live" {
  bot_id         = awscc_lex_bot.translation_bot.id
  bot_alias_name = "live"
  bot_version    = awscc_lex_bot_version.v1.bot_version

  bot_alias_locale_settings = [{
    locale_id = "en_US"
    bot_alias_locale_setting = {
      enabled   = true
      code_hook_specification = {
        lambda_code_hook = {
          code_hook_interface_version = "1.0"
          lambda_arn                  = var.lambda_function_arn
        }
      }
    }
  }]
}