FROM python:3.9.20-bookworm

COPY requirements.txt ./
RUN pip install -r requirements.txt
RUN pip install opentelemetry-instrumentation-ollama==0.39.4 --no-deps
RUN pip install -i https://test.pypi.org/simple/ dynatrace-opentelemetry-instrumentation-langchain==0.39.3a1 --no-deps

COPY ./public ./public
COPY ./destinations ./destinations
COPY app.py  ./

EXPOSE 8080

CMD [ "python", "app.py"]