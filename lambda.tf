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



# Remediation Lambda function and its IAM role/policy

#  IAM role the remediation Lambda assumes 
resource "aws_iam_role" "lambda_remediator" {
  name = "lambda-remediator-role"

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

# IAM policy for the remediation Lambda to send SSM commands and publish to SNS
resource "aws_iam_role_policy" "lambda_remediation_permissions" {
  name = "lambda-remediation-policy"
  role = aws_iam_role.lambda_remediator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "ssm:SendCommand"
        Effect = "Allow"
        Resource = [
          "arn:aws:ec2:eu-west-1:851725234293:instance/${aws_instance.k3s_node.id}",
          "arn:aws:ssm:eu-west-1::document/AWS-RunShellScript"
        ]
      },
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Attach the basic execution role to the remediation Lambda
resource "aws_iam_role_policy_attachment" "lambda_remediator_basic_execution" {
  role       = aws_iam_role.lambda_remediator.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

#  Package the Python file into a zip 
data "archive_file" "remediate_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/remediate.py"
  output_path = "${path.module}/lambda/remediate.zip"
}

resource "aws_lambda_function" "remediator" {
  function_name    = "alert-remediator"
  role             = aws_iam_role.lambda_remediator.arn
  handler          = "remediate.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.remediate_zip.output_path
  source_code_hash = data.archive_file.remediate_zip.output_base64sha256

  environment {
    variables = {
      INSTANCE_ID   = aws_instance.k3s_node.id
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

# Function URL for the remediation Lambda
resource "aws_lambda_function_url" "remediator_url" {
  function_name      = aws_lambda_function.remediator.function_name
  authorization_type = "NONE"
}

# Permissions for the remediation Lambda Function URL to allow public access
resource "aws_lambda_permission" "remediator_public_invoke" {
  statement_id           = "AllowPublicInvokeFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.remediator.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# Permissions for the remediation Lambda to be invoked publicly
resource "aws_lambda_permission" "remediator_public_invoke_function" {
  statement_id  = "AllowPublicInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediator.function_name
  principal     = "*"
}