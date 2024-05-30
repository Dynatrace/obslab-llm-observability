from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_community.document_loaders import BSHTMLLoader

from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain.chains.combine_documents import create_stuff_documents_chain
from langchain.chains import create_retrieval_chain
from langchain_community.callbacks import get_openai_callback
import logging
import sys
import os
from openai import OpenAI
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import uvicorn
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

from traceloop.sdk import Traceloop

from tokencost import calculate_completion_cost, calculate_prompt_cost

Traceloop.init()

# GLOBALS
RUN_LOCALLY = os.environ.get("RUN_LOCALLY", False)
OTEL_COLLECTOR_ENDPOINT = os.environ.get("OTEL_COLLECTOR_ENDPOINT", "localhost:4317")
OTEL_COLLECTOR_ENDPOINT_INSECURE = os.environ.get("OTEL_COLLECTOR_ENDPOINT_INSECURE", "False")
# Convert to boolean. Defaulting to False to support security by design.
if OTEL_COLLECTOR_ENDPOINT_INSECURE.lower() == "true":
    OTEL_COLLECTOR_ENDPOINT_INSECURE = True
else:
    OTEL_COLLECTOR_ENDPOINT_INSECURE = False
OPENAI_KEY = os.environ.get("OPENAI_API_KEY")




COMPLETION_LENGTH = os.environ.get("COMPLETION_LENGTH", 20)
CACHE_MINUTES = os.environ.get("CACHE_MINUTES", 60)
AI_MODEL = os.environ.get("AI_MODEL", "gpt-3.5-turbo")
AI_SYSTEM = "openai"
MAX_PROMPT_LENGTH = 50
AI_EMBEDDING_MODEL = "text-embedding-ada-002"
MAX_PROMPT_LENGTH = 50
retrieval_chain = None

# Initialise the logger...
logging.basicConfig(level=logging.INFO, filename="run.log")
logger = logging.getLogger(__name__)

# ################
# # CONFIGURE OPENTELEMETRY

resource = Resource.create({
    "service.name": "easytravel-ai-rag",
    "service.version": "0.1.0"
})

logger.info(f"OTEL_COLLECTOR_ENDPOINT: {OTEL_COLLECTOR_ENDPOINT}")
logger.info(f"OTEL_COLLECTOR_ENDPOINT_INSECURE: {OTEL_COLLECTOR_ENDPOINT_INSECURE}")

provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_COLLECTOR_ENDPOINT, insecure=OTEL_COLLECTOR_ENDPOINT_INSECURE))
provider.add_span_processor(processor)

# Sets the global default tracer provider
trace.set_tracer_provider(provider)

# Creates a tracer from the global tracer provider
otel_tracer = trace.get_tracer("my.tracer.name")

def prep_system():
    docs_list = []
    for item in os.listdir(path="destinations"):
        if item.endswith(".html"):
            item_docs_list = BSHTMLLoader(file_path=f"destinations/{item}").load()
            for item in item_docs_list:
                docs_list.append(item)

    embeddings = OpenAIEmbeddings(model="text-embedding-3-small")

    # Split Document into tokens
    text_splitter = RecursiveCharacterTextSplitter()
    documents = text_splitter.split_documents(docs_list)

    # Store in a local vector database: FAISS
    # https://github.com/facebookresearch/faiss
    logger.info("Loading documents into FAISS...")
    vector = FAISS.from_documents(documents, embeddings)

    logger.info("Initialising ChatGPT LLM...")
    llm = ChatOpenAI()

    prompt = ChatPromptTemplate.from_template("""Answer the following question based only on the provided context:

    <context>
    {context}
    </context>

    Question: {input}
                                              
    If no context is available respond with 'Sorry, I have no data on {input}'.""")

    document_chain = create_stuff_documents_chain(llm, prompt)

    retriever = vector.as_retriever()
    retrieval_chain = create_retrieval_chain(retriever, document_chain)
    return retrieval_chain

#############
# CONFIGURE 

openai_client = OpenAI(api_key=OPENAI_KEY)

############
# CONFIGURE ENDPOINTS

app = FastAPI()

####################################
@app.get("/api/v1/completion")
def submit_completion(prompt: str):
    with otel_tracer.start_as_current_span(name="/api/v1/completion") as current_span:
        if prompt:
            logger.info(f"Calling RAG to get the answer to the question: {prompt}...")
            response = None
            with get_openai_callback() as cb: 
                response = retrieval_chain.invoke({"input": prompt})

            # Log information for DQL to grab
            logger.info(f"Response: {response}. Using RAG. model={AI_MODEL}. prompt_tokens={cb.prompt_tokens}. completion_tokens={cb.completion_tokens}. total_tokens={cb.total_tokens}. total_cost={cb.total_cost}")

            
            return { "message": response['answer'] }
        else: # No, or invalid prompt given
            current_span.add_event(f"No prompt provided or prompt too long (over {MAX_PROMPT_LENGTH} chars)")
            return { "message": f"No prompt provided or prompt too long (over {MAX_PROMPT_LENGTH} chars)"}

                
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
    app.mount("/", StaticFiles(directory="public", html = True), name="public")
    #app.mount("/destinations", StaticFiles(directory="destinations", html = True), name="destinations")

    # Run the app using uvicorn
    if RUN_LOCALLY:
        uvicorn.run(app, host="0.0.0.0", port=8080, log_config="run-locally/logconf.ini")
    else:
        uvicorn.run(app, host="0.0.0.0", port=8080)
