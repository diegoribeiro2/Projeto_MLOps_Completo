resource "aws_iam_role" "mlflow-server-role" {  # A IAM Role (mlflow-server-role) permite que a EC2 assuma permissões para acessar outros serviços AWS (como o S3).
    name = "mlflow-server-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17",
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
resource "aws_iam_instance_profile" "mlflow-server-profile" {   # A Instance Profile é usada para vincular a role à instância EC2.
    name = "mlflow-server-profile"
    role = aws_iam_role.mlflow-server-role.name
}

resource "aws_instance" "mlflow-server" {
    ami           = "${var.ami_id}"
    instance_type = "t2.micro"
    key_name      = "${var.key_name}"
    tags = {
        Name = "mlflow-server"
    }
    iam_instance_profile = aws_iam_instance_profile.mlflow-server-profile.name
    vpc_security_group_ids = [ aws_security_group.mlflow-server-sg.id ]
    user_data = <<-EOF
    #!/bin/bash -x

    sudo yum update -y
    sudo yum install -y python3-pip

    sudo -u ec2-user bash << 'EOL'

    python3 -m venv /home/ec2-user/venv
    source /home/ec2-user/venv/bin/activate

    pip install --upgrade pip
    pip install mlflow boto3 psycopg2-binary

    EOL

    # Create a systemd service for MLflow
    sudo bash -c 'cat <<EOT > /etc/systemd/system/mlflow.service
    [Unit]
    Description=MLflow Server
    After=network.target

    [Service]
    User=ec2-user
    WorkingDirectory=/home/ec2-user
    ExecStart=/home/ec2-user/venv/bin/mlflow server -h 0.0.0.0 -p 5000 --backend-store-uri postgresql://mlflow:${var.mlflow_db_password}@${aws_db_instance.mlflow-db.endpoint}/mlflow_db --default-artifact-root s3://${aws_s3_bucket.mlflow-artifacts.bucket}
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOT'

    # Reload systemd and enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable mlflow
    sudo systemctl start mlflow
  EOF
}


resource "aws_security_group" "mlflow-server-sg" {
    name        = "mlflow-server-sg"
    description = "Allow SSH access"

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port   = 5000
        to_port     = 5000
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1" # -1 represents all protocols
        cidr_blocks = ["0.0.0.0/0"]
    }
}
resource "aws_db_instance" "mlflow-db" {
    identifier = "mlflow-db"
    db_name              = "mlflow_db"
    allocated_storage    = 5
    storage_type         = "gp2"
    engine               = "postgres"
    engine_version       = "16.3"
    instance_class       = "db.t3.micro"
    username             = "mlflow"
    password             = "mlflowmlflow"
    publicly_accessible  = false
    skip_final_snapshot  = true
    vpc_security_group_ids = [ aws_security_group.mlflow-db-sg.id ]
}

resource "aws_security_group" "mlflow-db-sg" {
    name        = "mlflow-db-sg"
    ingress {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        security_groups = [ aws_security_group.mlflow-server-sg.id ]
    }
}

# Referência para valores aleatórios: https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string
resource "random_string" "random" {
  length = 16
  special = false
  lower = true
  upper = false
}

resource "aws_s3_bucket" "mlflow-artifacts" {
    bucket = "mlflow-artifacts-${random_string.random.result}"
}

resource "aws_iam_role_policy" "mlflow-server-s3-access" {
    name = "mlflow-server-s3-access"
    role = aws_iam_role.mlflow-server-role.id

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                    "s3:PutObject",
                    "s3:GetObject",
                    "s3:ListBucket"
                ],
                Resource = [
                    aws_s3_bucket.mlflow-artifacts.arn,
                    "${aws_s3_bucket.mlflow-artifacts.arn}/*"
                ]
            }
        ]
    })
}