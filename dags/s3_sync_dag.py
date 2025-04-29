from airflow import DAG
from airflow.operators.bash import BashOperator

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
}

dag = DAG(
    "sync_dags_from_s3",
    default_args=default_args,
    description="Sincroniza dags do S3 pro airflow",
    schedule_interval=None,
    catchup=False,
)


sync_dags = BashOperator(
    task_id="sync_dags",
    bash_command="sudo aws s3 sync {{ dag_run.conf['s3_bucket'] }} {{ dag_run.conf['airflow_dags_folder'] }} --delete",
    dag=dag,
)

sync_dags
