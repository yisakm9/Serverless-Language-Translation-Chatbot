# Ensures the Service-Linked Role for Lex V1 exists.
# This is required for the bot to function correctly.
resource "aws_iam_service_linked_role" "lex" {
  aws_service_name = "lex.amazonaws.com"
}

# 1. Define the custom slot type for languages
resource "aws_lex_slot_type" "language" {
  name        = "Language"
  description = "Slot type for target languages"
  enumeration_value {
    value = "Spanish"
  }
  enumeration_value {
    value = "French"
  }
  enumeration_value {
    value = "German"
  }
  value_selection_strategy = "ORIGINAL_VALUE"
}

# 2. Define the primary intent for translation
resource "aws_lex_intent" "translate_text" {
  name = "TranslateText"

  # This section will be updated later to connect your Lambda function
  fulfillment_activity {
    type = "ReturnIntent"
  }

  sample_utterances = [
    "Translate something",
    "Can you translate for me",
    "Translate to {targetLanguage}",
  ]

  slot {
    name              = "sourceText"
    slot_type         = "AMAZON.FreeFormInput"
    slot_constraint   = "Required"
    value_elicitation_prompt {
      max_attempts = 2
      message {
        content_type = "PlainText"
        content      = "What text would you like to translate?"
      }
    }
  }

  slot {
    name              = "targetLanguage"
    slot_type         = aws_lex_slot_type.language.name
    slot_type_version = aws_lex_slot_type.language.version
    slot_constraint   = "Required"
    value_elicitation_prompt {
      max_attempts = 2
      message {
        content_type = "PlainText"
        content      = "Which language should I translate it to?"
      }
    }
  }
}

# 3. Define the Lex bot itself
resource "aws_lex_bot" "translation_bot" {
  name                        = var.bot_name
  child_directed              = false
  locale                      = "en-US"
  idle_session_ttl_in_seconds = 300
  process_behavior            = "BUILD"

  clarification_prompt {
    max_attempts = 2
    message {
      content_type = "PlainText"
      content      = "I'm sorry, I didn't understand. Can you please repeat that?"
    }
  }

  abort_statement {
    message {
      content_type = "PlainText"
      content      = "Sorry, I am not able to assist at this time."
    }
  }

  intent {
    intent_name    = aws_lex_intent.translate_text.name
    intent_version = aws_lex_intent.translate_text.version
  }

  # Ensure the service-linked role exists before creating the bot
  depends_on = [
    aws_iam_service_linked_role.lex
  ]
}

# 4. Create a "live" alias for the bot
resource "aws_lex_bot_alias" "live" {
  bot_name    = aws_lex_bot.translation_bot.name
  bot_version = aws_lex_bot.translation_bot.version
  name        = "live"
}