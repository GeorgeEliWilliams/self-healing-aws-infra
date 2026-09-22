# Output the public IP of the k3s node
output "instance_public_ip" {
  description = "Public IP of the k3s node"
  value       = aws_instance.k3s_node.public_ip
}

# Output the public DNS of the k3s node
output "instance_id" {
  description = "Instance ID of the k3s node"
  value       = aws_instance.k3s_node.id
}

# Output the SNS topic ARN for cluster alerts
output "sns_topic_arn" {
  description = "ARN of the SNS topic for cluster alerts"
  value       = aws_sns_topic.alerts.arn
}

# Output the Lambda function URL for the alert notifier
output "lambda_function_url" {
  description = "HTTPS endpoint for the alert notifier Lambda"
  value       = aws_lambda_function_url.alert_notifier_url.function_url
}

# Output the remediation Lambda function URL
output "remediator_function_url" {
  description = "HTTPS endpoint for the auto-remediation Lambda"
  value       = aws_lambda_function_url.remediator_url.function_url
}