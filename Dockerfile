FROM python:3-bookworm

#WORKDIR /home/node/app

COPY app.py  ./

COPY requirements.txt ./

RUN pip install -r requirements.txt

COPY . .

#COPY instrumentation.js ./

#RUN npm install

#COPY . .

EXPOSE 8080

# Original version
#CMD [ "node", "wbapp.js" ]

# My image
#CMD [ "node", "app.js" ]

# OpenTelemetry enabled
CMD [ "python", "app.py"]