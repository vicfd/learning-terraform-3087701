data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "blog" {
  name = "blog"
  tags = {
    Terraform = "true"
  }
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "blog_ssh_in" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.blog.id
}

resource "aws_security_group_rule" "blog_http_in" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.blog.id
}

resource "aws_security_group_rule" "blog_https_in" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.blog.id
}

resource "aws_security_group_rule" "blog_everything_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.blog.id
}

# Crear una política de IAM que permita acceso al bucket S3
data "aws_iam_policy_document" "s3_access_policy" {
  statement {
    actions   = ["s3:*"]
    resources = [
      "arn:aws:s3:::1234testvcitor",
      "arn:aws:s3:::1234testvcitor/*"
    ]
  }
}

# Crear un rol de IAM
resource "aws_iam_role" "my_instance_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Adjuntar la política al rol
resource "aws_iam_policy" "s3_access_policy" {
  name        = "S3AccessPolicy"
  description = "Policy to allow access to S3 bucket"
  policy      = data.aws_iam_policy_document.s3_access_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.my_instance_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Crear un perfil de instancia de IAM
resource "aws_iam_instance_profile" "my_instance_profile" {
  name = "MyInstanceProfile"
  role = aws_iam_role.my_instance_role.name
}

resource "aws_instance" "blog" {
  ami                    = data.aws_ami.app_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.blog.id]
  key_name      = "prueba" # Aquí especificamos la clave SSH "test"

  # Script de datos de usuario para crear el usuario vicfd
  user_data = <<-EOF
              #!/bin/bash
              useradd -m vicfd
              mkdir -p /home/vicfd/.ssh
              cp /home/bitnami/.ssh/authorized_keys /home/vicfd/.ssh/
              chown -R vicfd:vicfd /home/vicfd/.ssh
              echo "vicfd ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
              EOF

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y s3fs",
      "sudo mkdir /mnt/s3",
      "sudo s3fs my-bucket /mnt/s3 -o passwd_file=~/.passwd-s3fs -o allow_other -o umask=022"
    ]

  iam_instance_profile = aws_iam_instance_profile.my_instance_profile.name

  tags = {
    Name = "Learning Terraform"
  }
}