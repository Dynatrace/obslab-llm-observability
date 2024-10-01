from langchain_core.prompts import ChatPromptTemplate, PromptTemplate
from langchain_community.document_loaders import BSHTMLLoader

from langchain_community.chat_models import ChatOllama
from langchain_community.embeddings import OllamaEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain.chains.combine_documents import create_stuff_documents_chain
from langchain.chains import create_retrieval_chain
from langchain_pinecone import PineconeVectorStore

import logging
import os
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import uvicorn

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from traceloop.sdk import Traceloop
from traceloop.sdk.decorators import workflow

# disable traceloop telemetry
os.environ["TRACELOOP_TELEMETRY"] = "false"


def read_token():
    return os.environ.get("API_TOKEN", read_secret("token"))


def read_endpoint():
    return os.environ.get("OTEL_ENDPOINT", read_secret("endpoint"))


def read_pinecone_key():
    return read_secret("api-key")


def read_secret(secret: str):
    try:
        with open(f"/etc/secrets/{secret}", "r") as f:
            return f.read().rstrip()
    except Exception as e:
        print(f"No {secret} was provided")
        print(e)
        return ""


OTEL_ENDPOINT = read_endpoint()
if OTEL_ENDPOINT.endswith("/v1/traces"):
    OTEL_ENDPOINT = OTEL_ENDPOINT[: OTEL_ENDPOINT.find("/v1/traces")]

OLLAMA_ENDPOINT = os.environ.get("OLLAMA_ENDPOINT", "http://localhost:11434")

# GLOBALS
AI_MODEL = os.environ.get("AI_MODEL", "orca-mini:3b")
AI_SYSTEM = "llama"
AI_EMBEDDING_MODEL = os.environ.get("AI_EMBEDDING_MODEL", "orca-mini:3b")
MAX_PROMPT_LENGTH = 50
retrieval_chain = None

# Initialise the logger
logging.basicConfig(level=logging.INFO, filename="run.log")
logger = logging.getLogger(__name__)

# ################
# # CONFIGURE OPENTELEMETRY

resource = Resource.create(
    {"service.name": "travel-advisor", "service.version": "0.2.0"}
)

TOKEN = read_token()
headers = {"Authorization": f"Api-Token {TOKEN}"}

provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(
    OTLPSpanExporter(endpoint=f"{OTEL_ENDPOINT}/v1/traces", headers=headers)
)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
otel_tracer = trace.get_tracer("travel-advisor")

Traceloop.init(
    app_name="travel-advisor",
    api_endpoint=OTEL_ENDPOINT,
    disable_batch=True,
    headers=headers,
)


def prep_system():

    # Create the embedding
    embeddings = OllamaEmbeddings(model=AI_EMBEDDING_MODEL, base_url=OLLAMA_ENDPOINT)

    # Retrieve the source data
    docs_list = []
    for item in os.listdir(path="destinations"):
        if item.endswith(".html"):
            item_docs_list = BSHTMLLoader(file_path=f"destinations/{item}").load()
            for item in item_docs_list:
                docs_list.append(item)

    # Split Document into tokens
    text_splitter = RecursiveCharacterTextSplitter()
    documents = text_splitter.split_documents(docs_list)

    logger.info("Loading documents from PineCone...")
    vector = PineconeVectorStore.from_documents(
        documents, index_name="travel-advisor", embedding=embeddings
    )
    retriever = vector.as_retriever()

    logger.info("Initialising Llama LLM...")
    llm = ChatOllama(model=AI_MODEL, base_url=OLLAMA_ENDPOINT)

    prompt = ChatPromptTemplate.from_template(
        """Answer the following question based only on the provided context:

    <context>
    {context}
    </context>

    Question: {input}
                                              
    If no context is available respond with 'Sorry, I have no data on {input}'."""
    )

    document_prompt = PromptTemplate(
        input_variables=["page_content", "source"],
        template="content:{page_content}\nsource:{source}",
    )

    document_chain = create_stuff_documents_chain(
        llm=llm,
        prompt=prompt,
        document_prompt=document_prompt,
    )

    return create_retrieval_chain(retriever, document_chain)


############
# CONFIGURE ENDPOINTS

app = FastAPI()


####################################
@app.get("/api/v1/completion")
def submit_completion(prompt: str):
    with otel_tracer.start_as_current_span(name="/api/v1/completion") as span:
        return submit_completion(prompt, span)


@workflow(name="travelgenerator")
def submit_completion(prompt: str, span):
    if prompt:
        logger.info(f"Calling RAG to get the answer to the question: {prompt}...")
        response = retrieval_chain.invoke({"input": prompt}, config={})

        # Log information for DQL to grab
        logger.info(
            f"Response: {response}. Using RAG. model={AI_MODEL}. prompt={prompt}"
        )
        return {"message": response["answer"]}
    else:  # No, or invalid prompt given
        span.add_event(
            f"No prompt provided or prompt too long (over {MAX_PROMPT_LENGTH} chars)"
        )
        return {
            "message": f"No prompt provided or prompt too long (over {MAX_PROMPT_LENGTH} chars)"
        }


####################################
@app.get("/api/v1/thumbsUp")
@otel_tracer.start_as_current_span("/api/v1/thumbsUp")
def thumbs_up(prompt: str):
    logger.info(f"Positive user feedback for search term: {prompt}")


@app.get("/api/v1/thumbsDown")
@otel_tracer.start_as_current_span("/api/v1/thumbsDown")
def thumbs_down(prompt: str):
    logger.info(f"Negative user feedback for search term: {prompt}")


if __name__ == "__main__":
    retrieval_chain = prep_system()

    # Mount static files at the root
    app.mount("/", StaticFiles(directory="./public", html=True), name="public")
    # app.mount("/destinations", StaticFiles(directory="destinations", html = True), name="destinations")

    # Run the app using uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
