#!/usr/bin/env python3
"""
Basic LangChain Agent Example with Traceloop

This example demonstrates how to use Traceloop with a simple LangChain agent
to automatically trace agent execution, tool usage, and LLM calls.
"""

# Modified from here: https://github.com/traceloop-ai/traceloop/blob/main/examples/langchain/basic_agent.py
# Usage
# python slimmed.tool.calling.py --destination "San Francisco"     (defaults FROM to "Las Vegas")
# or
# python slimmed.tool.calling.py --location "Las Vegas "--destination "San Francisco"    (explicitly set the FROM location and TO location)

import argparse
import asyncio
import os, time
from traceloop.sdk import Traceloop
from traceloop.sdk.decorators import task
from langchain.agents import create_agent
from langchain.tools import tool
from langchain_ollama import ChatOllama
import requests
from pydantic import BaseModel
from typing import List
from haversine import haversine, Unit

PERFORM_TENANT_ID = "hci34192"
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "qwen3:0.6b")

# Initialize Traceloop
Traceloop.init(
    app_name="app-tool-calling",
    api_endpoint="http://localhost:4318",
    disable_batch=True
)
    
###################################
# START CLASSES
class TravelDistance(BaseModel):
    from_location: str
    to_location: str
    distance_km: float
    flight_time_hours: float

class DistanceResponse(BaseModel):
    status: str
    message: str
    distance_info: TravelDistance | None = None

class DailyForecast(BaseModel):
    date: str
    temp_max: float
    temp_min: float
    precipitation: float

class LocationCoordinates(BaseModel):
    location_name: str
    latitude: float
    longitude: float
    country: str
    display_name: str

class CoordinatesResponse(BaseModel):
    status: str
    message: str
    coordinates: LocationCoordinates | None = None

class WeatherForecast(BaseModel):
    location: str
    latitude: float
    longitude: float
    current_temperature: float
    current_conditions: str
    forecast_days: List[DailyForecast]

class WeatherResponse(BaseModel):
    status: str
    message: str
    forecast: WeatherForecast | None = None

# END CLASSES
###################################

@tool
async def get_location_coordinates(location_name: str):
    """
    Get coordinates for a location using Nominatim (OpenStreetMap) API.

    Args:
        location_name: Name of the city or location

    Returns:
        Latitude and longitude coordinates
    """
    print(f"Getting coordinates for location: {location_name}")

    try:
        # Add small delay to respect rate limits (Nominatim requires max 1 req/sec)
        time.sleep(1.1)

        url = "https://nominatim.openstreetmap.org/search"
        params = {"q": location_name, "format": "json", "limit": 1}
        headers = {"User-Agent": "TravelAgentDemo/1.0 (OpenTelemetry Sample App)"}

        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()

        data = response.json()

        if not data:
            return CoordinatesResponse(
                status="error", message=f"Location not found: {location_name}"
            )

        location_data = data[0]
        coordinates = LocationCoordinates(
            location_name=location_name,
            latitude=float(location_data.get("lat", 0.0)),
            longitude=float(location_data.get("lon", 0.0)),
            country=location_data.get("display_name", "").split(",")[-1].strip(),
            display_name=location_data.get("display_name", ""),
        )

        print(f"Received coordinates for {location_name}. Lat: {float(location_data.get("lat", 0.0))}. Lon: {float(location_data.get("lon", 0.0))}")

        return CoordinatesResponse(
            status="success",
            message=f"Coordinates found for {location_name}",
            coordinates=coordinates,
        )

    except requests.RequestException as e:
        print(f"Error getting coordinates: {str(e)}")
        return CoordinatesResponse(
            status="error", message=f"Failed to get coordinates: {str(e)}"
        )
    
@tool
async def get_weather(location: str, latitude: float, longitude: float) -> str:
    """Get the current weather for a location."""
    print(f"Getting weather forecast for {location} (lat: {latitude}, lon: {longitude})")

    try:
        # Add small delay to respect rate limits
        time.sleep(0.5)

        url = "https://api.open-meteo.com/v1/forecast"
        params = {
            "latitude": latitude,
            "longitude": longitude,
            "current": "temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code",
            "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum",
            "timezone": "auto",
            "forecast_days": 1,
        }

        response = requests.get(url, params=params, timeout=10)
        response.raise_for_status()

        data = response.json()
        current = data.get("current", {})
        daily = data.get("daily", {})

        # Map weather codes to conditions (simplified)
        weather_code = current.get("weather_code", 0)
        conditions = {
            0: "Clear sky",
            1: "Mainly clear",
            2: "Partly cloudy",
            3: "Overcast",
            45: "Foggy",
            61: "Light rain",
            63: "Moderate rain",
            65: "Heavy rain",
            71: "Light snow",
            95: "Thunderstorm",
        }
        current_conditions = conditions.get(weather_code, "Unknown")

        forecast_days = []
        times = daily.get("time", [])
        temp_max = daily.get("temperature_2m_max", [])
        temp_min = daily.get("temperature_2m_min", [])
        precip = daily.get("precipitation_sum", [])

        for i in range(min(len(times), len(temp_max), len(temp_min), len(precip))):
            daily_forecast = DailyForecast(
                date=times[i] if i < len(times) else "",
                temp_max=float(temp_max[i])
                if i < len(temp_max) and temp_max[i] is not None
                else 0.0,
                temp_min=float(temp_min[i])
                if i < len(temp_min) and temp_min[i] is not None
                else 0.0,
                precipitation=float(precip[i])
                if i < len(precip) and precip[i] is not None
                else 0.0,
            )
            forecast_days.append(daily_forecast)

        forecast = WeatherForecast(
            location=location,
            latitude=float(latitude),
            longitude=float(longitude),
            current_temperature=float(current.get("temperature_2m", 0.0))
            if current.get("temperature_2m") is not None
            else 0.0,
            current_conditions=current_conditions,
            forecast_days=forecast_days,
        )

        return WeatherResponse(
            status="success",
            message=f"Weather forecast retrieved for {location}",
            forecast=forecast,
        )
    except:
        return WeatherResponse(
            status="error",
            message=f"Something went wrong getting a WeatherReponse for {location}"
        )

@tool
async def calculate_travel_distance(
    from_location: str,
    to_location: str,
    from_lat: float,
    from_lon: float,
    to_lat: float,
    to_lon: float,
) -> DistanceResponse:
    """
    Calculate distance and estimated flight time between two locations.
    Uses Haversine formula for distance calculation.

    Args:
        from_location: Starting location name
        to_location: Destination location name
        from_lat: Starting latitude
        from_lon: Starting longitude
        to_lat: Destination latitude
        to_lon: Destination longitude

    Returns:
        Distance and flight time information
    """
    print(f"Calculating distance from {from_location} (lat: {from_lat}, lon: {from_lon}) to {to_location} (lat: {to_lat}, lon: {to_lon})")

    from_point = (from_lat, from_lon)
    to_point = (to_lat, to_lon)
    distance_km_rounded = round(haversine(from_point, to_point, unit=Unit.KILOMETERS), 2)
    flight_time_hours_rounded = round(distance_km_rounded, 2) / 500.0 # Assumes a aircraft speed of 500km/h

    print(f"{from_location} <> {to_location} is approx. {distance_km_rounded} km and thus approximately a {flight_time_hours_rounded} hr(s) flight")

    distance_info = TravelDistance(
            from_location=from_location,
            to_location=to_location,
            distance_km=distance_km_rounded,
            flight_time_hours=flight_time_hours_rounded,
        )

    return DistanceResponse(
            status="success",
            message=f"Distance calculated: {distance_km_rounded} km, approximately {flight_time_hours_rounded} hours flight",
            distance_info=distance_info,
        )

#############################
# MAIN LOGIC
#############################

tools = [get_location_coordinates, get_weather, calculate_travel_distance]

# Define the LLM
llm = ChatOllama(
    model=OLLAMA_MODEL,
    temperature=0.2,
)

# Create the agent

agent = None

async def main():

    print(f"Starting Agentic Travel Planning... Please wait...")

    agent = create_agent(model=llm, tools=tools, name="travel-planning-agent")

    parser = argparse.ArgumentParser(description="Travel Planning Agent Demo")
    parser.add_argument("--location", default="Las Vegas")
    parser.add_argument("--destination", default="San Francisco")

    args = parser.parse_args()

    agent_question = f"Answer three questions: 1) What's the weather like in {args.destination}? 2) How far away from {args.location} is {args.destination}? 3) What is the flight time from {args.location} to {args.destination}?"

    print("")
    print(f"Planning journey and gathering information from: {args.location} to {args.destination}.")
    print("This takes about 2-3 minutes. Please be patient...")
    print("")
    print(f"The agent is asked this: {agent_question}")
    print("The agent is given access to 3 'tools' (or capabilities):")
    print("  1) The ability to get the latitude and longitude for a particular place")
    print("  2) The ability to calculate the distance between two places")
    print("  3) The ability to retrieve the current weather for a particular place")
    print("")
    print("The agent decides if / when to call these tools in the pursuit of the requested answers.")
    print("")
    print("Watch the agent work autonomously below...")
    
    # This will be automatically traced by Traceloop
    result = await agent.ainvoke({"messages": [
       {"role": "system", "content": "You are a helpful assistant that can check the weather and tell me how far places are from each other. If a tool exists for a task, you must use it. Call tools more than once when required. Prefer a tool than calling the model."},
       {"role": "user", "content": agent_question}
    ]})

    print("="*20)
    print("YOUR RESULTS ARE IN!")
    print("="*20)

    for message in result["messages"]:
        print(type(message))
        print(message)
        print("-"*20)

    print("")
    print(">"*20)
    print("")
    print("WOW! That's a lot of output!")
    print("You could save the above messages into a log file and send them to Dynatrace.")
    print("But there's a more user friendly way using distributed traces.")
    print("Click this link to see the distributed trace and head back to the tutorial in Dynatrace which explains the trace.")
    print(f"https://{PERFORM_TENANT_ID}.apps.dynatrace.com/ui/apps/dynatrace.distributedtracing/explorer?filter=dt.entity.service.entity.name+=+app-tool-calling+endpoint.name+=+travel-planning-agent.workflow")

# Example usage
if __name__ == "__main__":    
    asyncio.run(main())