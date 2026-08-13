# security_groups.tf

resource "aws_security_group" "k3s_sg" {
  name        = "k3s-security-group"
  description = "Security group for k3s cluster"
  vpc_id      = aws_vpc.k3s_vpc.id

  tags = {
    Name = "k3s-security-group"
  }
}

# --- SSH from your IP only ---
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.k3s_sg.id
  description       = "SSH from my IP"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.my_ip
}

# --- Kubernetes API from your IP only ---
resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  security_group_id = aws_security_group.k3s_sg.id
  description       = "Kubernetes API from my IP"
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.my_ip
}

# --- All outbound traffic allowed ---
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.k3s_sg.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}