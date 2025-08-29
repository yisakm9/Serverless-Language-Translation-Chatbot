# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Fetch AWS account details automatically
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# 1. Call the IAM module to create the Lambda execution role
module "iam" {
  source = "../../modules/iam" # Path to the module

  lambda_execution_role_name = "${var.project_name}-lambda-role-dev"
}

# 2. Call the Lambda module to create the function
module "lambda_function" {
  source = "../../modules/lambda_function" # Path to the module

  function_name = "${var.project_name}-translator-dev"
  iam_role_arn  = module.iam.lambda_execution_role_arn # Use output from the IAM module
  
  # The path is relative to this file's location
  source_code_path = "../../src/lambda_translator/index.py" 
}

# 3. Call the Lex module to create the bot
module "lex_bot" {
  source = "../../modules/lex_bot" # Path to the module

  

  # Corrected: Replaced all hyphens with underscores to create a valid name.
  bot_name            = "${replace(var.project_name, "-", "_")}_bot_dev"
  
  lambda_function_arn = module.lambda_function.lambda_function_arn # Use output from the Lambda module
  aws_region          = data.aws_region.current.id
  aws_account_id      = data.aws_caller_identity.current.account_id
}