# IAM role for Lambda function to send alerts to SNS topic
resource "aws_iam_role" "lambda_alert_notifier" {
  name = "lambda-alert-notifier-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy to allow Lambda to publish to the SNS topic
resource "aws_iam_role_policy" "lambda_sns_publish" {
  name = "lambda-sns-publish-policy"
  role = aws_iam_role.lambda_alert_notifier.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Basic logging permission (so Lambda can write to CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_alert_notifier.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Package the Python file into a zip (Lambda deploys as a zip archive)
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/notify.py"
  output_path = "${path.module}/lambda/notify.zip"
}

resource "aws_lambda_function" "alert_notifier" {
  function_name    = "alert-notifier"
  role             = aws_iam_role.lambda_alert_notifier.arn
  handler          = "notify.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

# Function URL - gives Lambda a real HTTPS endpoint, no API Gateway needed
resource "aws_lambda_function_url" "alert_notifier_url" {
  function_name      = aws_lambda_function.alert_notifier.function_name
  authorization_type = "NONE"
}

# Permissions for the Lambda Function URL to allow public access
resource "aws_lambda_permission" "allow_public_function_url" {
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.alert_notifier.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "allow_public_invoke" {
  statement_id  = "AllowPublicInvokeViaFunctionUrl"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_notifier.function_name
  principal     = "*"
}