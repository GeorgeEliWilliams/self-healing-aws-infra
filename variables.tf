variable "my_ip" {
  description = "public IP for SSH/K8s API access"
  type        = string
}

variable "alerts_email" {
  description = "Email address to receive SNS cluster alerts"
  type        = string
}