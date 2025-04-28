resource "aws_iam_role" "airflow-server-role" {
  name = "airflow-server-role"
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

resource "aws_iam_instance_profile" "airflow-server-profile" {
  name = "airflow-server-profile"
  role = aws_iam_role.airflow-server-role.name
}

# bucket para armazenar os dags do airflow
resource "aws_s3_bucket" "airflow-dags" {
  bucket = "airflow-dags-${random_string.random.result}"
}

# pasta local com os dags do airflow
locals {
  dags_folder = "${path.module}/dags"
}

# copia os dags para o bucket
resource "aws_s3_object" "airflow-dags" {
  for_each = fileset(local.dags_folder, "**/*.py")
  bucket   = aws_s3_bucket.airflow-dags.bucket
  key      = each.value
  source   = "${local.dags_folder}/${each.value}"
}
resource "aws_instance" "airflow-server" {
  ami           = var.ami_id
  instance_type = "t3.xlarge"
  key_name      = var.key_name
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  tags = {
    Name = "airflow-server"
  }
  iam_instance_profile = aws_iam_instance_profile.airflow-server-profile.name
  vpc_security_group_ids = [aws_security_group.airflow-server-sg.id]
  user_data            = <<-EOF
    #!/bin/bash -x
    export AIRFLOW_HOME=/home/ec2-user/airflow

    sudo yum update -y
    sudo yum install -y python3-pip

    sudo -u ec2-user bash << 'EOL'

    python3 -m venv /home/ec2-user/airflow/venv
    source /home/ec2-user/airflow/venv/bin/activate

    pip install --upgrade pip
    pip install 'apache-airflow[amazon]'
    pip install psycopg2-binary
    pip install virtualenv
    pip install asyncpg 
    pip install --upgrade transformers
    pip install torch 

    export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:${var.airflow_db_password}@${aws_db_instance.airflow-db.endpoint}/airflow_db
    # fazer aparecer o trigger with config
    export AIRFLOW__WEBSERVER__SHOW_TRIGGER_FORM_IF_NO_PARAMS=True
    export AIRFLOW__CORE__LOAD_EXAMPLES=False
    export AIRFLOW__SCHEDULER__DAG_DIR_LIST_INTERVAL=5

    airflow db migrate

    airflow variables set SERVIDOR_MLFLOW "http://${aws_instance.mlflow-server.public_ip}:5000" 
    airflow variables set PATH_DADOS "${aws_s3_bucket.data-lake.bucket}"

    airflow users create --role Admin --username admin --email admin --firstname admin --lastname admin --password admin

    # copiar os dags do bucket para a pasta de dags
    aws s3 cp s3://${aws_s3_bucket.airflow-dags.bucket} /home/ec2-user/airflow/dags/ --recursive

    airflow webserver -p 8080 -D
    airflow scheduler

    EOL
  EOF
}


resource "aws_security_group" "airflow-server-sg" {
  name        = "airflow-server-sg"
  description = "Permitir acesso SSH e Airflow"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Adiciona regra de entrada na porta 8080 para acessar o Airflow
  ingress {
    from_port   = 8080
    to_port     = 8080
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


resource "aws_db_instance" "airflow-db" {
  identifier             = "airflow-db"
  db_name                = "airflow_db"
  allocated_storage      = 5
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t3.micro"
  username               = "airflow"
  password               = var.airflow_db_password
  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.airflow-db-sg.id]
}

resource "aws_security_group" "airflow-db-sg" {
  name = "airflow-db-sg"
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.airflow-server-sg.id]
  }
}

resource "aws_iam_role_policy" "airflow-server-s3-access" {
  name = "airflow-server-s3-access"
  role = aws_iam_role.airflow-server-role.id

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
          "${aws_s3_bucket.mlflow-artifacts.arn}/*",
          aws_s3_bucket.data-lake.arn,
          "${aws_s3_bucket.data-lake.arn}/*",
        ]
      },
      # permissão para acessar o bucket de dags do airflow
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.airflow-dags.arn,
          "${aws_s3_bucket.airflow-dags.arn}/*"
        ]
      }

    ]
  })
}
