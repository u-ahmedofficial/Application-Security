provider "aws" {
  # Define your provider configuration here (e.g., region)
  region = "us-east-1"
}

resource "aws_instance" "vault_server" {
  ami           = var.vault_ami
  instance_type = var.vault_instance_type
  security_groups = [aws_security_group.vault_sg.name]
  iam_instance_profile = aws_iam_instance_profile.vault_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              # Your user data script here
              EOF

  tags = {
    Name = "VaultServer"
  }
}

resource "aws_iam_role" "vault_role" {
  name = "VaultInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "vault_policy" {
  name = "AccessAndUpdateVaultSecret"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret",
        ]
        Effect = "Allow"
        Resource = aws_secretsmanager_secret.vault_secret.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vault_policy_attachment" {
  role       = aws_iam_role.vault_role.name
  policy_arn = aws_iam_policy.vault_policy.arn
}

resource "aws_iam_instance_profile" "vault_instance_profile" {
  name = "VaultInstanceProfile"
  role = aws_iam_role.vault_role.name
}

resource "aws_secretsmanager_secret" "vault_secret" {
  name        = "VaultSecret"
  description = "Secret for the Vault server"
}

resource "aws_security_group" "vault_sg" {
  description = "Security Group for Vault Server"
  ingress = [
    {
      from_port   = 8200
      to_port     = 8200
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
  ]
}

resource "aws_cloudtrail" "vault_cloudtrail" {
  name                          = "VaultActivity"
  s3_bucket_name                = aws_s3_bucket.vault_cloudtrail_bucket.id
  include_global_service_events = true

  event_selector {
    read_write_type = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::SecretsManager::Secret"
      values = [aws_secretsmanager_secret.vault_secret.arn]
    }
  }
}

resource "aws_s3_bucket" "vault_cloudtrail_bucket" {
  bucket = "vault-cloudtrail-bucket"
  acl    = "private"
}

variable "vault_instance_type" {
  description = "EC2 Instance Type"
  default     = "t2.micro"
}

variable "vault_ami" {
  description = "AMI ID for Vault Server"
  default     = "ami-09eb2ed0e9c2f6126"
}

output "vault_server_ip" {
  value = aws_instance.vault_server.public_ip
}
