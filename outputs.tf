output "airflow-server-public-ip" {
  value = aws_instance.airflow-server.public_ip
}

output "mlflow-server-public-ip" {
  value = aws_instance.mlflow-server.public_ip
}

output "airflow-db-endpoint" {
  value = aws_db_instance.airflow-db.endpoint
}

output "mlflow-db-endpoint" {
  value = aws_db_instance.mlflow-db.endpoint
}

output "inference-server-public-ip" {
  value = aws_instance.inference-server.public_ip
}
