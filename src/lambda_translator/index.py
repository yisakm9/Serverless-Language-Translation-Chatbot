# src/lambda_translator/index.py

import json
import boto3

# It's a best practice to initialize the client outside the handler
translate = boto3.client('translate')

def lambda_handler(event, context):
    """
    This function is triggered by Amazon Lex. It translates text using Amazon Translate.
    """
    # Extract the slots (variables) from the Lex V2 event
    slots = event['sessionState']['intent']['slots']
    source_text = slots['sourceText']['value']['interpretedValue']
    target_language_name = slots['targetLanguage']['value']['interpretedValue']

    # Simple mapping of user-friendly language names to ISO 639-1 codes
    # A real-world app might use a more robust method like a DynamoDB table
    language_codes = {
        "spanish": "es",
        "french": "fr",
        "german": "de",
        "italian": "it",
        "japanese": "ja",
        "portuguese": "pt",
        "russian": "ru",
    }

    target_language_code = language_codes.get(target_language_name.lower())

    # Default response if the language is not supported
    response_message = f"I'm sorry, I don't support translation to {target_language_name} right now."

    if target_language_code:
        try:
            # Call the Amazon Translate service
            translation_response = translate.translate_text(
                Text=source_text,
                SourceLanguageCode='auto',  # Let Translate auto-detect the source language
                TargetLanguageCode=target_language_code
            )
            translated_text = translation_response['TranslatedText']
            response_message = f"'{source_text}' in {target_language_name} is: {translated_text}"
        except Exception as e:
            print(f"Error during translation: {e}") # Log the error for debugging
            response_message = "Sorry, I couldn't translate that. Please try again."

    # This is the specific response format that Amazon Lex V2 expects
    return {
        "sessionState": {
            "dialogAction": {
                "type": "Close"
            },
            "intent": {
                "name": event['sessionState']['intent']['name'],
                "state": "Fulfilled"
            }
        },
        "messages": [
            {
                "contentType": "PlainText",
                "content": response_message
            }
        ]
    }