terraform {
  required_providers {           # Aqui definiu a versão do provedor AWS (boa pratica definir, senao o terraform baixa automaticamente o último e pode dar algum erro)
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70.0"
    }
  }
  backend "s3" {                 # aqui criou o bucket para guardar na AWS o arquivo de estado do terraform (sempre bom fazer isso em projetos compartilhados)
    bucket = "projeto-mlops-completo"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }
}

provider "aws" {                # aqui defini o fuso-horario (tudo tem que ser criado neste fuso-horario para funcionar)
  region = "us-east-2"
}
