from langchain_core.tools import tool

from models.bedrock import Bedrock


@tool
def movie_quote(city: str) -> str:
    """Returns a quote from a movie"""
    prompt = f"Provide a quote from the movie {city}"
    response = Bedrock().chat(prompt)
    return response
