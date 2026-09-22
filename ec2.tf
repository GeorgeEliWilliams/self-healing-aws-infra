# data "aws_ami" "al2023" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["al2023-ami-*-x86_64"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }. pin AMI ID instead of always querying most_recent, prevents surprise instance replacement on AMI releases

resource "aws_key_pair" "k3s_key" {
  key_name   = "k3s-portfolio-key"
  public_key = file("~/.ssh/k3s-portfolio-key.pub")
}

resource "aws_instance" "k3s_node" {
  ami                    = "ami-02fbb3a1708d9c2cd"
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.k3s_public_subnet.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  key_name               = aws_key_pair.k3s_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name


  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
  #!/bin/bash

  # Install and start SSM Agent
  dnf install -y amazon-ssm-agent
  systemctl enable amazon-ssm-agent
  systemctl start amazon-ssm-agent

  # Install k3s
  curl -sfL https://get.k3s.io | sh -
EOF

  tags = {
    Name = "k3s-node"
  }
}

# IAM role for EC2 instances to allow SSM access
resource "aws_iam_role" "ec2_ssm_role" {
  name = "k3s-node-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the AmazonSSMManagedInstanceCore policy to the EC2 IAM role
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create an instance profile for the EC2 instances to use the IAM role
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "k3s-node-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}