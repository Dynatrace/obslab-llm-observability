from langchain_core.tools import tool

from models.bedrock import Bedrock


@tool
def travel_advice(city: str) -> str:
    """Provide travel advice for the given city"""
    prompt = f"Give travel advise in a paragraph of max 50 words about {city}"
    response = Bedrock().chat(prompt)
    print(f"Tool answer: -->{response}<--")
    return response
