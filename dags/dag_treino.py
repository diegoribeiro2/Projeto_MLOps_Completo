import logging
from datetime import datetime

from airflow.decorators import dag, task
from airflow.models import Variable
from airflow.providers.amazon.aws.hooks.s3 import S3Hook

# Definir os argumentos padrão para o DAG
args_padrao = {
    "owner": "airflow",
    "depends_on_past": False,
}


logger = logging.getLogger(__name__)

tracking_uri = Variable.get("SERVIDOR_MLFLOW")
path_dados = Variable.get("PATH_DADOS")


@dag(
    "treino_modelo_dag",
    default_args=args_padrao,
    description="DAG simples para treino de um modelo HuggingFace",
    catchup=False,  # Não voltar no tempo para executar tarefas
    schedule=None,  # None para desabilitar o agendamento e rodar apenas uma vez
    start_date=datetime(2023, 11, 13),
    tags=["treino", "huggingface"],
)
def dag_treinar_modelo():
    """DAG para treino de um modelo de ML"""

    @task
    def baixar_do_s3(bucket_name, file_name="sentiment_dataset.csv"):
        hook = S3Hook()
        path = hook.download_file(
            key=file_name,
            bucket_name=bucket_name,
            local_path="/tmp/",
            preserve_file_name=True,
        )
        logger.info(f"Dataset baixado para {path}")
        return path

    @task.virtualenv(
        task_id="preprocessamento",
        requirements=["pandas"],
        system_site_packages=False,
    )
    def preprocessamento(path: str):
        """Essa função executa o preprocessamento dos dados.

        Returns:
            str: Caminho para o arquivo csv com os dados preprocessados
        """
        import pandas as pd

        df = pd.read_csv(path)
        df[["review_text_processed", "polarity"]][:200].to_csv(
            "/tmp/preprocessed_data.csv"
        )

        return "/tmp/preprocessed_data.csv"

    @task.virtualenv(
        task_id="treino_modelo",
        requirements=[
            "pandas",
            "transformers>=4.31.0",
            "mlflow",
            "numpy<2",
            "boto3",
            "datasets",
            "evaluate",
            "torch @ https://download.pytorch.org/whl/cpu/torch-2.1.0%2Bcpu-cp39-cp39-linux_x86_64.whl",
            "accelerate",
            "torchvision",
        ],
        system_site_packages=False,
    )
    def treino(csv_path: str, tracking_server_uri: str):
        """Essa função executa o treino do modelo.

        Args:
            csv_path (str): Caminho para o arquivo csv com os dados preprocessados

        Returns:
            bool: True se o treino foi executado com sucesso
        """

        from functools import partial

        import evaluate
        import mlflow
        import numpy as np
        import pandas as pd
        from datasets import Dataset
        from mlflow import MlflowClient
        from transformers import (
            AutoModelForSequenceClassification,
            AutoTokenizer,
            Trainer,
            TrainingArguments,
            pipeline,
        )
        from transformers.integrations import MLflowCallback

        mlflow.set_tracking_uri(tracking_server_uri)
        TOKENIZER = AutoTokenizer.from_pretrained(
            "distilbert/distilbert-base-uncased-finetuned-sst-2-english"
        )
        MODEL = AutoModelForSequenceClassification.from_pretrained(
            "distilbert/distilbert-base-uncased-finetuned-sst-2-english"
        )

        METRIC = evaluate.load("accuracy")

        def tokenize_function(examples, tokenizer):
            return tokenizer(examples["text"], padding="max_length", truncation=True)

        def compute_metrics(eval_pred):
            logits, labels = eval_pred
            predictions = np.argmax(logits, axis=-1)
            return METRIC.compute(predictions=predictions, references=labels)

        dataset = pd.read_csv(csv_path)
        dataset = dataset.dropna(subset=["review_text_processed", "polarity"])

        dataset = (
            Dataset.from_pandas(dataset)
            .map(
                lambda batch: {
                    "label": int(batch["polarity"]),
                    "text": batch["review_text_processed"].strip(),
                }
            )
            .select_columns(["text", "label"])
        ).map(partial(tokenize_function, tokenizer=TOKENIZER), batched=True)

        # se o experimento não existir, ele será criado
        if not mlflow.get_experiment_by_name("predicao-sentimento"):
            mlflow.create_experiment("predicao-sentimento")
        experiment = mlflow.get_experiment_by_name("predicao-sentimento")
        dataset = dataset.train_test_split(test_size=0.3)
        with mlflow.start_run(experiment_id=experiment.experiment_id) as run:
            trainer = Trainer(
                model=MODEL,
                args=TrainingArguments(
                    per_device_train_batch_size=4,
                    per_device_eval_batch_size=4,
                    # evaluation_strategy="epoch",
                    save_strategy="epoch",
                    output_dir="/tmp/",
                    # load_best_model_at_end=True,
                    num_train_epochs=1,
                ),
                train_dataset=dataset["train"],
                eval_dataset=dataset["test"],
                # compute_metrics=compute_metrics,
                callbacks=[MLflowCallback()],
            )
            trainer.train()
            classification_pipeline = pipeline(
                task="text-classification", model=MODEL, tokenizer=TOKENIZER
            )
            mlflow.transformers.log_model(
                transformers_model=classification_pipeline,
                artifact_path=f"modelo-predicao-sentimento-{run.info.run_id}",
                registered_model_name="modelo-predicao-sentimento",
            )

            # essa etapa poderia estar em outro operador, após outras validacoes
            client = MlflowClient()

            latest_version_info = client.get_latest_versions(
                "modelo-predicao-sentimento", stages=["None"]
            )
            latest_version = latest_version_info[0].version

            # colocando o modelo em "produção"
            client.set_registered_model_alias(
                "modelo-predicao-sentimento", "producao", latest_version
            )
        return True

    baixar_op = baixar_do_s3(bucket_name=path_dados)
    preprocessamento_op = preprocessamento(path=baixar_op)
    treino_op = treino(csv_path=preprocessamento_op, tracking_server_uri=tracking_uri)


dag_treinar_modelo()
