FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt /app/requirements.txt

# instalar as dependências
RUN pip install -r requirements.txt

# copiar os arquivos para o container
COPY app.py /app/

# expor a porta 8501 (streamlit)
EXPOSE 8501

# rodar o servidor
CMD ["streamlit", "run", "app.py"]
