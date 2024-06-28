import os
import time
import datetime
from openai import OpenAI
import uvicorn.logging
import weaviate
from fastapi import FastAPI
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import uvicorn
import weaviate.connect
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.trace import Status, StatusCode
import logging
from traceloop.sdk import Traceloop

RUN_LOCALLY = os.environ.get("RUN_LOCALLY", False)
OTEL_COLLECTOR_ENDPOINT = os.environ.get("OTEL_COLLECTOR_ENDPOINT", "localhost:4318")
OPENAI_KEY = os.environ.get("OPENAI_API_KEY")
WEAVIATE_ENDPOINT = os.environ.get("WEAVIATE_ENDPOINT", None)
WEAVIATE_CONNECT_TIMEOUT_SECONDS = 90
WEAVIATE_READ_TIMEOUT_SECONDS = 90
WEAVIATE_STARTUP_PERIOD_SECONDS = 30
COMPLETION_LENGTH = os.environ.get("COMPLETION_LENGTH", 20)
CACHE_MINUTES = os.environ.get("CACHE_MINUTES", 60)
AI_MODEL = os.environ.get("AI_MODEL", "gpt-4")
AI_SYSTEM = "openai"
MAX_PROMPT_LENGTH = 50
AI_EMBEDDING_MODEL = os.environ.get("AI_EMBEDDING_MODEL", "text-embedding-ada-002")
OPENAI_BASE_URL = os.environ.get("OPENAI_BASE_URL", "")
OTEL_COLLECTOR_ENDPOINT_INSECURE = os.environ.get("OTEL_COLLECTOR_ENDPOINT_INSECURE", False)

Traceloop.init(app_name="my app name", api_endpoint=OTEL_COLLECTOR_ENDPOINT)

# Temporary until LLM Semantic conventions
#  are released: https:#github.com/traceloop/semantic-conventions/blob/4ee7433cd9bbda00bca0f118c1230ff13eac62e5/docs/gen-ai/llm-spans.md
#  Use these as keys. For example:
#  span.setAttribute(SEMCONV_TMP_GENAI_SYSTEM: "openai");

# Required (according to spec)
# SEMCONV_TMP_GENAI_REQUEST_MODEL = "gen_ai.request.model"                      # eg. "gpt-4"
# SEMCONV_TMP_GENAI_SYSTEM = "gen_ai.system"                                    # eg. "openai"

# # Recommended (according to spec)
# SEMCONV_TMP_GENAI_REQUEST_MAX_TOKENS = "gen_ai.request.max_tokens"            # eg. 100
# SEMCONV_TMP_GENAI_REQUEST_TEMPERATURE = "gen_ai.request.temperature"          # eg. 0.0
# SEMCONV_TMP_GENAI_REQUEST_TOP_P = "gen_ai.request.top_p"                      # eg. 1.0
# SEMCONV_TMP_GENAI_REQUEST_FINISH_REASONS = "gen_ai.request.finish_reasons"    # eg. ["stop"]
# SEMCONV_TMP_GENAI_RESPONSE_ID = "gen_ai.response.id"                          # eg. "chatcmpl-123"
# SEMCONV_TMP_GENAI_RESPONSE_MODEL = "gen_ai.response.model"                    # eg. "gpt-4-0613"
# SEMCONV_TMP_GENAI_USAGE_COMPLETION_TOKENS = "gen_ai.usage.completion_tokens"  # eg. 180
# SEMCONV_TMP_GENAI_USAGE_PROMPT_TOKENS = "gen_ai.usage.prompt_tokens"          # eg. 100

# # My addition
# SEMCONV_GENAI_REQUEST_PROMPT = "gen_ai.request.prompt"                        # eg. "Give me destination advice about the city of Sydney"
# SEMCONV_GENAI_RESPONSE = "gen_ai.response.content"                            # eg. "Explore the Sydney markets, beautiful beaches and Opera House."

#logging.basicConfig(filename='aguvicorn.log', level=logging.INFO)
logger = logging.getLogger("uvicorn")

################
# CONFIGURE OPENTELEMETRY

resource = Resource.create({
    "service.name": "easytravel-ai",
    "service.version": "0.1.0"
})

provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_COLLECTOR_ENDPOINT))
provider.add_span_processor(processor)

# Sets the global default tracer provider
trace.set_tracer_provider(provider)

# Creates a tracer from the global tracer provider
otel_tracer = trace.get_tracer("my.tracer.name")

#############
# CONFIGURE 

if OPENAI_BASE_URL != "":
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {OPENAI_KEY}"
    }
    openai_client = OpenAI(base_url=OPENAI_BASE_URL, default_headers=headers)
else:
    openai_client = OpenAI(api_key=OPENAI_KEY)

############
# CONFIGURE ENDPOINTS

app = FastAPI()

####################################
@app.get("/api/v1/completion")
def submit_completion(prompt: str):
    with otel_tracer.start_as_current_span(name="/api/v1/completion") as current_span:
        logger.info(f"Input prompt was: {prompt}")
        cache_hit = False

        if prompt:
            with otel_tracer.start_as_current_span("process-prompt") as span:
                clean_text = prompt.strip().lower()
                if len(clean_text) > 0 and len(clean_text) < 50:
                    # span.add_event("prompt length is valid", attributes={ "prompt-length": len(prompt)})

                    if WEAVIATE_ENDPOINT:
                        logger.info(f"Weaviate endpoint is set. Trying to use the cache: {WEAVIATE_ENDPOINT}")
                        emb_vector = get_embedding_vector(clean_text)
                        if emb_vector:
                            result = get_cached_prompt(emb_vector)
                            logger.info(result)
                            if len(result['data']['Get']['Travel']) > 0 and not cache_outdated(result['data']['Get']['Travel'][0]['creation_timestamp']): # cache hit
                                # current_span.set_attribute(key=SEMCONV_GENAI_RESPONSE, value=result['data']['Get']['Travel'][0]['answer'])

                                # Important log line for DT processing
                                logger.info(f"Got valid cached response using weaviate and {AI_EMBEDDING_MODEL}")

                                return { "message": result['data']['Get']['Travel'][0]['answer'] } # Return cached response
                            else: # Cached response not available, generate new completion
                                advice = get_completion(clean_text)
                                # Store in semantic cache
                                cache_completion(clean_text, emb_vector, advice['message'])
                                # Now return answer
                                # current_span.set_attribute(key=SEMCONV_GENAI_RESPONSE, value=advice['message'])
                                return advice
                        else: # emb_vector not available
                            logger.info("OpenAI embedding creation failed")
                            current_span.add_event("OpenAI embedding creation failed")
                            # current_span.set_status(Status(StatusCode.ERROR))
                            return { "message": "OpenAI embedding creation failed" }
                    else: # WEAVIATE_ENDPOINT not available
                        current_span.add_event("Weaviate endpoint not available. Returning result from live LLM")
                        # current_span.set_attribute(SEMCONV_GENAI_RESPONSE)
                        advice = get_completion(clean_text)
                        return advice
                else:
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


##########################################
# FUNCTIONS

@otel_tracer.start_as_current_span("create_cache_collection")
def create_cache_collection(collection_name):

    # with otel_tracer.start_as_current_span(name="create_cache_collection", attributes={ "collection-name": collection_name}) as current_span:
    with otel_tracer.start_as_current_span(name="create_cache_collection") as current_span:
        if WEAVIATE_ENDPOINT:
            weaviate_client = weaviate.Client(url=WEAVIATE_ENDPOINT, timeout_config=(WEAVIATE_CONNECT_TIMEOUT_SECONDS, WEAVIATE_READ_TIMEOUT_SECONDS), startup_period=WEAVIATE_STARTUP_PERIOD_SECONDS)

            try:
                weaviate_client.schema.create_class(schema_class={
                    "class": collection_name,
                    "properties": [{
                        "name": "prompt",
                        "dataType": ["text"],
                    },
                    {
                        "name": "answer",
                        "dataType": ["text"],
                    },
                    {
                        "name": "creation_timestamp",
                        "dataType": ["text"],
                    }]
                })

                # current_span.set_attribute(key="collection-created", value=True)
                logger.info(">> Weaviate collection created.")
            except:
                # current_span.set_attribute(key="collection-created", value=False)
                logger.info(">> Weaviate collection already exists.")
        
@otel_tracer.start_as_current_span("get_completion")
def get_completion(prompt):
    # current_span = trace.get_current_span()
    # current_span.set_attribute(key="input-prompt", value=prompt)
    
    prompt = f"Give travel advise in a paragraph of max {COMPLETION_LENGTH} words about {prompt}"
    # current_span.set_attribute(key="full-prompt", value=prompt)

    chat_completion = openai_client.chat.completions.create(
        messages=[{ "role": "user", "content": prompt }],
        model=AI_MODEL
    )

    # important info log for extracting token counts on the Dynatrace side
    logger.info(chat_completion)

    json_data = {
        "message": chat_completion.choices[0].message.content
    }

    # current_span.set_attributes({ SEMCONV_TMP_GENAI_RESPONSE_ID: chat_completion.id, SEMCONV_TMP_GENAI_RESPONSE_MODEL : chat_completion.model, SEMCONV_TMP_GENAI_REQUEST_FINISH_REASONS: chat_completion.choices[0].finish_reason, SEMCONV_GENAI_RESPONSE: json_data['message']})

    return json_data

@otel_tracer.start_as_current_span("get_embedding_vector")
def get_embedding_vector(text):
    # current_span = trace.get_current_span()

    logger.info(f"getting embedding vector for text: {text}")

    input = {
        "model": AI_EMBEDDING_MODEL,
        "input": text
    }
    # current_span.set_attribute(key="model", value=AI_EMBEDDING_MODEL)
    # current_span.set_attribute(key="input", value=text)

    resp = openai_client.embeddings.create(input=text, model=AI_EMBEDDING_MODEL, encoding_format="float")

    return resp.data[0].embedding

@otel_tracer.start_as_current_span("get_cached_prompt")
def get_cached_prompt(vector):
        if WEAVIATE_ENDPOINT:
            MAX_DISTANCE = 0.01
            weaviate_client = weaviate.Client(url=WEAVIATE_ENDPOINT, timeout_config=(WEAVIATE_CONNECT_TIMEOUT_SECONDS, WEAVIATE_READ_TIMEOUT_SECONDS), startup_period=WEAVIATE_STARTUP_PERIOD_SECONDS)
            result = weaviate_client.query.get(class_name="Travel", properties=["answer", "prompt", "creation_timestamp"]).with_near_vector(content={ 
                "vector": vector,
                "distance": MAX_DISTANCE,
                "limit": 1 
            }).with_limit(1).do()

            return result

@otel_tracer.start_as_current_span("cache_outdated")
def cache_outdated(timestamp):
    current_time_datetime = datetime.datetime.fromtimestamp(time.time())
    creation_timestamp_datetime = datetime.datetime.fromtimestamp(int(timestamp)/1000)

    # current_span = trace.get_current_span()

    time_difference_seconds = (current_time_datetime-creation_timestamp_datetime).total_seconds()
    logger.info(f"Time Difference in seconds: {time_difference_seconds}")

    # current_span.set_attribute(key="time-delta", value=time_difference_seconds)

    # Divide seconds by 60 to transform to mins
    if time_difference_seconds/60 > CACHE_MINUTES: # cached entry is too old
        # current_span.set_attribute(key="cache-outdated", value=True)
        logger.info("[cache_outdated] True")
        return True
    else: # cached entry is NOT too old
        # current_span.set_attribute(key="cache-outdated", value=False)
        logger.info("[cache_outdated] False")
        return False

@otel_tracer.start_as_current_span("cache_completion")
def cache_completion(prompt, prompt_vector, answer):
    #logger.info(f"[cache_completion] prompt: {prompt}. prompt_vector: {prompt_vector}. answer: {answer}")
    if WEAVIATE_ENDPOINT:
        weaviate_client = weaviate.Client(url=WEAVIATE_ENDPOINT, timeout_config=(WEAVIATE_CONNECT_TIMEOUT_SECONDS, WEAVIATE_READ_TIMEOUT_SECONDS), startup_period=WEAVIATE_STARTUP_PERIOD_SECONDS)
        logger.info(f"[cache_completion] Inserting to Weaviate. Answer: {answer} for prompt: {prompt}")
        weaviate_client.data_object.create(data_object={
            "prompt": prompt,
            "answer": answer,
            "creation_timestamp": str(round(time.time()*1000))
        }, class_name="Travel", vector=prompt_vector)

if __name__ == "__main__":

    # Mount static files at the root
    app.mount("/", StaticFiles(directory="public", html = True), name="public")

    # Create cache collection (only occurs if weaviate is available)
    create_cache_collection('Travel')

    # Run the app using uvicorn
    if RUN_LOCALLY:
        uvicorn.run(app, host="0.0.0.0", port=8080, log_config="run-locally/logconf.ini")
    else:
        uvicorn.run(app, host="0.0.0.0", port=8080)