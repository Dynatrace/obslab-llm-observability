FROM python:3.9.20-bookworm

COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY app.py  ./
COPY ./public ./public
COPY ./destinations ./destinations
COPY ./models ./models
COPY ./pipeline ./pipeline
COPY ./tools ./tools
COPY ./utils ./utils

EXPOSE 8080

CMD [ "python", "app.py"]