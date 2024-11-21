FROM python:3.9.20-bookworm

COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY ./public ./public
COPY ./destinations ./destinations
COPY app.py  ./

EXPOSE 8080

CMD [ "python", "app.py"]