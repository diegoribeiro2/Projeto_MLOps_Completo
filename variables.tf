variable "ami_id" {
  description = "Imagem da instância AWS"
}

variable "key_name" {
  description = "Nome do par de chaves que vai ser usado para acessar instância"
}

variable "airflow_db_password" {
  description = "Senha para acessar a base de dados do Airflow"
}

variable "mlflow_db_password" {
  description = "Senha para acessar a base de dados do MLFlow"
}