import os
from typing import Dict, Optional, Union

import mlflow
import mlflow.pyfunc
from fastapi import FastAPI
from pydantic import BaseModel

# acessar o servidor MLFlow agora na cloud
mlflow.set_tracking_uri(os.environ["REGISTRO_MLFLOW"])

# Cria aplicação FastAPI
app = FastAPI()

# Carrega o modelo que está em produção
MODELO = mlflow.pyfunc.load_model("models:/modelo-predicao-sentimento@producao")


def _calcular_predicao(texto: str) -> Dict[str, Union[str, float]]:
    """Calcula as prediçoes dos sentimentos

    Args:
        texto (str): texto

    Returns:
        Dict[str, Union[str, float]]: contém o score e o sentimento (POSITIVE ou NEGATIVE)
    """
    return MODELO.predict(texto).T.to_dict()[0]


# Define modelo de dado para resposta da API
class Predicao(BaseModel):
    """Modelo de dado para resposta da API"""

    predicao: str
    score: float


class Texto(BaseModel):
    """Modelo de dado para entrada da API"""

    texto: str
    token: Optional[str] = None


@app.get("/")
def home():
    """Rota inicial da API"""
    return {"message": "Bem-vindo à API de exemplo!"}


# # Rotas da API
@app.post("/predicao/", response_model=Predicao)
def predicao(texto: Texto):
    """Predição de sentimento

    Args:
        texto (Texto): Texto a ser classificado
    Returns:
        Predicao: Predicao com a predição e o score
    """
    predicao = _calcular_predicao(texto=texto.texto)
    return Predicao(predicao=predicao["label"], score=predicao["score"])
