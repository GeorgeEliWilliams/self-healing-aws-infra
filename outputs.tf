output "instance_public_ip" {
  description = "Public IP of the k3s node"
  value       = aws_instance.k3s_node.public_ip
}

output "instance_id" {
  description = "Instance ID of the k3s node"
  value       = aws_instance.k3s_node.id
}