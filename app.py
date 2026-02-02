import logging
import os
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import uvicorn
from ollama import chat
from ollama import ChatResponse
from traceloop.sdk import Traceloop
from traceloop.sdk.decorators import task
from guardrails import Guard
from typing import Dict
from guardrails.validators import FailResult, PassResult, register_validator, ValidationResult

# Initialise traceloop
# 1. Point OpenTelemetry data to the local collector instance
# 2. Disable batching to stream telemetry ASAP (useful for demos)

Traceloop.init(app_name="ai-travel-advisor", api_endpoint="http://localhost:4318", disable_batch=True)

OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "qwen3:0.6b")

# Initialise the logger
logging.basicConfig(level=logging.INFO, filename="run.log")
logger = logging.getLogger(__name__)

############
# CONFIGURE ENDPOINTS

app = FastAPI()

CITY_COUNTRY_LIST = list()
try:
    with open("countries-cities.csv", mode="r", encoding="UTF-8") as file:
        CITY_COUNTRY_LIST = file.readlines()
except:
    logger.warning("City and Country CSV missing. Guardrail won't work!")

@task(name="is-travel-related-guardrail")
@register_validator(name="is-travel-related", data_type="string")
def banned(value, metadata: Dict) -> ValidationResult:
    # Your logic here
    # Write standard code, call APIs or other LLMS
    # Do whatever you want here...

    # v2 Is this a valid travel request or something else?
    # 1. The user input is split (by whitespace)
    # 2. For each piece, an attempt is made to find it in the "cities and countries list (loaded from a CSV)
    # 3. Guardrail decisions:
    #    - If a piece matches, the query is likely to be related to travel = Guardrail passes.
    #    - If a piece does not match, the query is unlikely to be travel related = Guardrail fails.
    #
    # Examples:
    # "Give me tech stock recommendations for 2026" = Fail
    # "Give me travel advice about Paris" = Pass
    FOUND = False

    for place in CITY_COUNTRY_LIST:
        # If a match has already been found
        # Save time and don't bother searching the rest of the list
        if FOUND: break

        input_parts = value.lower().split()
        place_parts = place.lower().split()

        for token in input_parts:
            # ignore any single or chars like 'a', 'i' or 'c' or 'in'
            # This prevents phrases like: ["which", "stocks", "should", "i", "invest", "in"...]
            # from validating against cities like ["Qala", "i", "Naw"] or ["feldenkirchen", "in", "karnten"]
            # It's not perfect, but guardrails never are...
            if len(token) <= 2: continue

            if token.strip() in place_parts:
                print(f"Found a match for {token.strip()} in {place_parts}")
                FOUND = True
    if not FOUND:
        # This input is unlikely to be a travel query
        return FailResult(error_message=f"Banned topic for input: {value}")
    else:
        # This input is likely to be a travel query
        return PassResult()

####################################
@app.get("/api/v1/completion")
@task(name="get_destination_advice")
def submit_completion(prompt: str):
        
        # Step 1: Check input with guardrail
        try:
            # Initialise a Guard to use the custom banned guardrail
            guard = Guard().use(banned())

            # Trigger an evaluation
            # If the guardrail fails, an exception is triggered
            # Meaning don't execute the "real" call and jump to the except block
            guard.parse(prompt)

            # Step 2: Only call the LLM if the prompt is acceptable
            # Due to the potential exception above, this only happens
            # for a "clean" (or "acceptable") input
            response: ChatResponse = chat(model=OLLAMA_MODEL, messages=[{
                    "role": "system",
                    "content": "# Role: City expert.\n# Task: \nProvide three positive things to do for the given city.\n# Response Laws\n* Provide a MAXIMUM of three items.\n* Provide a numbered, short, bulletpoint advice for destinations."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ])
        except Exception as e:
            # Format the response like valid `response` object
            # So the frontend can display the error seamlessly
            return {
                 "message": {
                      "content": str(e)
                }
            }
        return response


####################################
@app.get("/api/v1/thumbsUp")
@task(name="thumbs_up")
def thumbs_up(prompt: str):
    logger.info(f"Positive user feedback for search term: {prompt}")

@app.get("/api/v1/thumbsDown")
@task(name="thumbs_down")
def thumbs_down(prompt: str):
    logger.info(f"Negative user feedback for search term: {prompt}")


if __name__ == "__main__":

    print("The app is running. Please go to http://localhost:8080")

    # Mount static files at the root
    app.mount("/", StaticFiles(directory="./public", html=True), name="public")

    # Run the app using uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
