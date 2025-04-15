import requests
import streamlit as st

st.title("Deixe aqui a sua review do nosso produto!")
review = st.text_input("Escreva sua review")
if review:
    backend_url = "http://backend:8000/predicao"
    resposta = requests.post(backend_url, json={"texto": review})
    if resposta.status_code != 200:
        st.error("erro!")
    resposta = resposta.json()
    if resposta["predicao"] == "POSITIVE":
        st.write("Ficamos muito felizes!")
    else:
        st.write("Lamentamos não ter atendido sua expectativa. Obrigado pela participação!")
