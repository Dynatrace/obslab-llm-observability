import logging
import os
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
import uvicorn

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from traceloop.sdk import Traceloop
from traceloop.sdk.decorators import workflow

from models.bedrock import Bedrock
from pipeline.agentic import Agentic
from pipeline.basic import Basic
from pipeline.langchain import LangChain
from utils import format_message
from utils.secrets import read_secret

# disable traceloop telemetry
os.environ["TRACELOOP_TELEMETRY"] = "false"
# configure OTel accumulation method
os.environ["OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE"] = "delta"


def read_token():
    return os.environ.get("API_TOKEN", read_secret("token"))


def read_endpoint():
    return os.environ.get("OTEL_ENDPOINT", read_secret("endpoint"))


OTEL_ENDPOINT = read_endpoint()
if OTEL_ENDPOINT.endswith("/v1/traces"):
    OTEL_ENDPOINT = OTEL_ENDPOINT[: OTEL_ENDPOINT.find("/v1/traces")]


# Initialise the logger
logging.basicConfig(level=logging.INFO, filename="run.log")
logger = logging.getLogger(__name__)

# ################
# # CONFIGURE OPENTELEMETRY

resource = Resource.create(
    {"service.name": "travel-advisor", "service.version": "0.3.0"}
)

TOKEN = read_token()
headers = {"Authorization": f"Api-Token {TOKEN}"}

otel_tracer = trace.get_tracer("travel-advisor")

Traceloop.init(
    app_name="travel-advisor",
    api_endpoint=OTEL_ENDPOINT,
    disable_batch=True,
    headers=headers,
)

## Pipelines

bedrock = Bedrock()
basic = Basic()
langchain = LangChain()
agentic = Agentic()

pipelines = {
    "none": basic,
    "rag": langchain,
    "agentic": agentic,
}

############
# CONFIGURE ENDPOINTS

app = FastAPI()


@app.exception_handler(HTTPException)
async def validation_exception_handler(request, exc):
    return JSONResponse(exc.detail, status_code=500)


####################################
@app.get("/api/v1/completion")
def submit_completion(prompt: str, pipeline: str):
    with otel_tracer.start_as_current_span(
        name="/api/v1/completion", kind=trace.SpanKind.SERVER
    ) as span:
        return submit_workflow(prompt, pipeline, span)


@workflow(name="travel_answer_generator")
def submit_workflow(prompt: str, pipeline: str, span: trace.Span):
    clean_prompt = prompt.lower().strip()
    if clean_prompt:
        p = pipeline.lower()
        if not p in pipelines:
            raise HTTPException(
                status_code=404,
                detail=format_message("Sorry, the selected framework doesn't exist"),
            )
        pipeline = pipelines[p]
        return pipeline.start(bedrock, clean_prompt)
    else:  # No, or invalid prompt given
        span.set_status(trace.status.StatusCode.ERROR, "Invalid prompt")
        return format_message("Sorry, the prompt provided is invalid")


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
    # Mount static files at the root
    app.mount("/", StaticFiles(directory="./public", html=True), name="public")

    # Run the app using uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
