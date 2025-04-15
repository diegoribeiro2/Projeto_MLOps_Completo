# 🛠️ Arquitetura Completa de MLOps na AWS com Terraform e GitHub Actions

Este projeto implementa uma arquitetura completa de **MLOps na AWS**, integrando as principais ferramentas do ecossistema de Machine Learning com automação de infraestrutura e deploy.

---

## 📌 Tecnologias Utilizadas

- **Terraform** – Provisionamento da infraestrutura como código (IaC)
- **GitHub Actions** – Pipeline de CI/CD para deploy automatizado
- **MLflow** – Rastreamento de experimentos e modelos
- **Airflow** – Orquestração de pipelines de machine learning
- **FastAPI** – Servidor REST para servir modelos
- **Streamlit** – Dashboard para visualização de resultados
- **RDS (PostgreSQL)** – Armazenamento de metadados
- **S3** – Repositório de modelos e DAGs

---

## ⚙️ Visão Geral da Arquitetura

| Componente         | Tecnologia              | Função Principal                                     |
|--------------------|--------------------------|------------------------------------------------------|
| Servidor de Tracking | MLflow (EC2)           | Registro e versionamento de experimentos e modelos  |
| Orquestrador        | Airflow (EC2)           | Agendamento e execução das DAGs de ML               |
| API/Interface       | FastAPI + Streamlit (EC2)| Disponibilização dos modelos e dashboards           |
| Banco de Dados      | RDS (PostgreSQL)        | Armazenamento de metadados (MLflow e Airflow)       |
| Armazenamento       | S3                      | Buckets para artefatos do MLflow e DAGs do Airflow  |
| CI/CD               | GitHub Actions          | Automatização do deploy via Terraform               |

---

## 🧩 Etapas da Implementação

### 1. Provisionamento com Terraform
- Configuração do provedor AWS
- Criação das instâncias EC2, RDS e buckets S3
- Scripts de inicialização automatizados com injeção de variáveis

### 2. Configuração do MLflow
- Container Docker configurado na EC2
- Conexão segura com RDS para armazenar metadados

### 3. Setup do Airflow
- Instância EC2 dedicada com recursos otimizados (t3.small)
- Integração com RDS em schema separado (`airflow`)
- DAGs armazenadas no bucket S3

### 4. Deploy da API (FastAPI + Streamlit)
- FastAPI para servir modelos treinados diretamente via MLflow
- Streamlit para dashboards interativos
- Comunicação via `MLFLOW_TRACKING_URI` apontando para a EC2 do MLflow

### 5. Banco de Dados RDS
- PostgreSQL com schemas separados para MLflow e Airflow
- Alto desempenho e suporte nativo

### 6. Buckets S3
- `mlflow-artifacts-bucket`: modelos e artefatos
- `airflow-dags-bucket`: pipelines (DAGs)

### 7. CI/CD com GitHub Actions
- Workflow automatizado dispara `terraform apply` ao detectar push
- Secrets protegidos no GitHub para armazenar chaves AWS

---

## 🔄 Fluxo CI/CD

```text
Push no GitHub → GitHub Actions roda Terraform → Infra atualizada automaticamente

