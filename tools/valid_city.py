import re

from models.bedrock import Bedrock

regex = re.compile("[^a-zA-Z]")

from langchain_core.tools import tool


@tool
def valid_city(city: str) -> bool:
    """Returns if the input is a valid city"""
    prompt = f"Is {city} a city? respond only with yes or no."
    response = Bedrock().chat(prompt)
    response = regex.sub("", response).lower()
    print(f"Tool answer: -->{response}<--")
    return response == "yes"
