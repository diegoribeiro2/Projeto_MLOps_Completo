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
Antes de criar os recursos, definimos o provedor AWS no arquivo main.tf, especificando a região onde os serviços serão implantados.

Por que isso é importante?

O Terraform precisa saber em qual região da AWS os recursos serão provisionados.
Garante que toda a infraestrutura seja criada de forma consistente:

- Configuração do provedor AWS
- Criação das instâncias EC2, RDS e buckets S3
- Scripts de inicialização automatizados com injeção de variáveis

### 2. Configuração do MLflow
O MLflow é responsável por rastrear experimentos e modelos. Para isso:

Usamos uma instância EC2 para facilitar o deploy.
O MLflow é configurado para se conectar a um banco de dados RDS (PostgreSQL), onde armazena metadados.

Como a conexão MLflow → RDS funciona?
O Terraform automaticamente injeta o endpoint do RDS no script de inicialização da EC2.
O MLflow usa essa conexão para persistir experimentos, parâmetros e métricas.

Os modelos são armazenadas em um bucket S3

### 3. Setup do Airflow
O Airflow gerencia pipelines de dados (DAGs). Para sua configuração:

Utilizamos uma instância EC2 um pouco mais robusta (t3.small) devido ao maior consumo de memória.
Assim como o MLflow, o Airflow se conecta ao mesmo RDS, mas em um schema diferente (airflow).

Qual a vantagem de usar RDS compartilhado?
Reduz custos, pois um único banco de dados serve a dois sistemas.
Facilita o gerenciamento de backups e monitoramento.

As DAGs são armazenadas em um bucket S3

### 4. Deploy da API (FastAPI + Streamlit)
Esta instância hospeda:

- FastAPI: API REST para servir modelos treinados.
- Streamlit: Interface interativa para visualização de resultados.

Como a API se comunica com o MLflow?
O código da FastAPI configura o MLFLOW_TRACKING_URI para apontar para a EC2 do MLflow.
Isso permite registrar e recuperar modelos diretamente do servidor de tracking.

### 5. Banco de Dados RDS
Um banco PostgreSQL é criado para armazenar:

- Metadados do MLflow (experimentos, runs, modelos).
- Metadados do Airflow (DAGs, tarefas, histórico de execução).

Por que PostgreSQL?

É suportado nativamente pelo MLflow e Airflow.
Oferece bom desempenho para operações de metadados.

### 6. Buckets S3
Dois buckets são provisionados:

- mlflow-artifacts-bucket: Armazena modelos treinados e artefatos.
- airflow-dags-bucket: Contém os scripts de pipeline (DAGs) do Airflow.

Vantagens do uso do S3:

Durabilidade e alta disponibilidade e Integração nativa com MLflow e Airflow.

### 7. CI/CD com GitHub Actions
Para evitar deploy manual, configuramos um workflow no GitHub Actions que:

Aplica o Terraform automaticamente ao detectar um push no repositório.
Usa secrets para armazenar credenciais da AWS de forma segura.


A infraestrutura é atualizada sem intervenção manual.

---

## 🔄 Fluxo CI/CD

```text
Push no GitHub → GitHub Actions roda Terraform → Infra atualizada automaticamente

