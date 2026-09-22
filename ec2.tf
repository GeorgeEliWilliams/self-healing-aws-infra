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
# }

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

  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    curl -sfL https://get.k3s.io | sh -
  EOF

  tags = {
    Name = "k3s-node"
  }
}

