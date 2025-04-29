# bucket para colocar as pastas do backend e frontend
resource "aws_s3_bucket" "inference-server" {
  bucket = "inference-server-${random_string.random.result}"
}

# Arquivos locais que serão enviados para o bucket
locals {
  docker_compose_file = "docker-compose.yml"
  directories = {
    "backend"  = "backend"
    "frontend" = "frontend"
  }

  files = flatten([
    for dir, path in local.directories : [
      for file in fileset(path, "**/*") : {
        dir  = dir
        path = path
        file = file
      }
    ]
  ])
}


resource "aws_s3_object" "upload_files" {
  for_each = { for item in local.files : "${item.dir}/${item.file}" => item }
  bucket   = aws_s3_bucket.inference-server.bucket
  key      = "${each.value.dir}/${each.value.file}"
  source   = "${each.value.path}/${each.value.file}"
  etag     = filemd5("${each.value.path}/${each.value.file}")
}

resource "aws_s3_object" "upload_docker_compose" {
  bucket = aws_s3_bucket.inference-server.bucket
  key    = local.docker_compose_file
  source = "${path.module}/docker-compose.yml"
  etag   = filemd5("${path.module}/docker-compose.yml")
}


# Permissões para a instância EC2

resource "aws_iam_role" "inference-server-role" {
  name = "inference-server-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "inference-server-profile" {
  name = "inference-server-profile"
  role = aws_iam_role.inference-server-role.name
}

resource "aws_iam_role_policy" "inference-server-policy" {
  name = "inference-server-policy"
  role = aws_iam_role.inference-server-role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
        ],
        Resource = [
          aws_s3_bucket.inference-server.arn,
          "${aws_s3_bucket.inference-server.arn}/*"
        ]
      },
      # permissoes para os artefatos do mlflow
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ],
        Resource = [
          aws_s3_bucket.mlflow-artifacts.arn,
          "${aws_s3_bucket.mlflow-artifacts.arn}/*"
        ]
      }
    ]
    }
  )
}


# Instância EC2

resource "aws_security_group" "inference-server-sg" {
  name        = "inference-server-sg"
  description = "Grupo de seguranca para a instancia de inferencia"

  # Acessar o backend
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Acessar o frontend
  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "inference-server" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.inference-server-sg.id]
  iam_instance_profile   = aws_iam_instance_profile.inference-server-profile.name
  tags = {
    Name = "inference-server"
  }
  # volume de 20GB
  root_block_device {
    volume_size = 20
  }

  user_data = <<-EOF
              #!/bin/bash
              # Instalação do Docker e do docker-compose
              sudo yum update -y
              sudo yum -y install docker
              sudo service docker start
              sudo usermod -a -G docker ec2-user
              sudo chmod 666 /var/run/docker.sock
              # Instalação do docker-compose
              sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
              sudo chmod +x /usr/local/bin/docker-compose
              # Copiar as pastas do bucket para o servidor
              aws s3 cp s3://${aws_s3_bucket.inference-server.bucket} /home/ec2-user/ --recursive
              # Subir o docker-compose
              cd /home/ec2-user
              export REGISTRO_MLFLOW=http://${aws_instance.mlflow-server.public_ip}:5000
              echo "REGISTRO_MLFLOW=http://${aws_instance.mlflow-server.public_ip}:5000" > /home/ec2-user/.env  # adicionei essa linha para guardar a varaivel permanetemente
              docker-compose up -d
              EOF
}
