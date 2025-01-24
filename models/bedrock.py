import boto3
import json
import os

from models import Model
from utils.secrets import read_secret

from langchain_aws.embeddings.bedrock import BedrockEmbeddings
from langchain_aws.llms.bedrock import BedrockLLM


class Bedrock(Model):

    def __init__(self) -> None:
        super().__init__()
        key = os.environ.get("AWS_ACCESS_KEY_ID", read_secret("aws-key"))
        sec = os.environ.get("AWS_SECRET_ACCESS_KEY", read_secret("aws-secret"))
        self.__embedding_model = os.environ.get(
            "AWS_EMBEDDING_MODEL", "amazon.titan-embed-text-v1"
        )
        self.__model = os.environ.get("AWS_MODEL", "amazon.titan-text-lite-v1")
        self.__guardrail_id = os.environ.get("AWS_GUARDRAIL_ID", "")

        self.__client = boto3.client(
            "bedrock-runtime",
            region_name=os.environ.get("AWS_DEFAULT_REGION", "eu-central-1"),
            aws_access_key_id=key,
            aws_secret_access_key=sec,
        )
        self.__langchain_embedding = BedrockEmbeddings(
            client=self.__client,
            model_id=self.__embedding_model,
        )
        self.__langchain_llm = BedrockLLM(
            client=self.__client,
            model_id=self.__model,
        )

    def embedding(self, prompt):
        native_request = {"inputText": prompt}
        request = json.dumps(native_request)
        response = self.__client.invoke_model(
            modelId=self.__embedding_model, body=request
        )
        embed = json.loads(response["body"].read())
        return embed["embedding"]

    def chat(self, prompt) -> str:
        native_request = {
            "inputText": prompt,
            "textGenerationConfig": {
                "maxTokenCount": 512,
                "temperature": 0.5,
            },
        }
        request = json.dumps(native_request)
        if self.__guardrail_id and self.__guardrail_id != "":
            api_response = self.__client.invoke_model(
                modelId=self.__model,
                body=request,
                guardrailIdentifier=self.__guardrail_id,
                guardrailVersion="DRAFT",
                trace="ENABLED",
            )
        else:
            api_response = self.__client.invoke_model(
                modelId=self.__model,
                body=request,
            )
        response = json.loads(api_response["body"].read())
        return response["results"][0]["outputText"]

    def langchain_embedding(self):
        return self.__langchain_embedding

    def langchain_llm(self):
        return self.__langchain_llm
