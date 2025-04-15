FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt /app/requirements.txt

# instalar as dependências
RUN pip install -r requirements.txt

# copiar os arquivos para o container
COPY resposta.py /app/resposta.py

# expor a porta 8000
EXPOSE 8000

# rodar o servidor
CMD ["uvicorn", "resposta:app", "--host", "0.0.0.0", "--port", "8000"]
