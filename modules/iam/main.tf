
# 1. Define the trust policy that allows Lambda to assume this role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# 2. Create the IAM role for the Lambda function
resource "aws_iam_role" "lambda_execution_role" {
  name               = var.lambda_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# 3. Attach the basic Lambda execution policy for CloudWatch logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 4. Attach the policy that allows calling the Amazon Translate service
resource "aws_iam_role_policy_attachment" "translate_readonly" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/TranslateReadOnly"
}