# EasyTravel GPT Travel Advisor

Demo application for giving travel advice written in Python. Observability signals by [OpenTelemetry](https://opentelemetry.io).

Uses OpenAI ChatGPT to generate advice for a given destination.

![title](screenshot.png)

## [>> Click here to start the hands on tutorial](https://dynatrace-perfclinics.github.io/obslab-llm-observability)


## Developer Information Below

### Run Locally with Weaviate Cache

- Download the [latest Weaviate binary from GitHub](https://github.com/weaviate/weaviate/releases/latest). Add it to your `PATH`.
- Download the [latest Dynatrace OpenTelemetry collector binary from GitHub](https://github.com/Dynatrace/dynatrace-otel-collector/releases). Add it to your `PATH`.

```
##### 1. Start Weaviate

set PROMETHEUS_MONITORING_ENABLED=true
weaviate --host 0.0.0.0 --port 8000 --scheme http

##### 2. Configure these variables and Start Collector
#####  Token needs: logs.ingest, metrics.ingest and openTelemetryTrace.ingest permissions

set DT_ENDPOINT=https://abc12345.live.dynatrace.com/api/v2/otlp
set API_TOKEN=dt0c01.******.******
dynatrace-otel-collector.exe --config ./run-locally/otelcol-config.yaml

##### Start app
set OPENAI_API_KEY=sk-proj-**********
set WEAVIATE_ENDPOINT=http://localhost:8000
# Disable usage telemetry that is sent to Traceloop
set TRACELOOP_TELEMETRY=false
python app.py
```

![opentelemetry trace](.devcontainer/images/get-completion-trace.png)

--------------------------

### Deploy on a Local K8S Cluster

You will need [Docker](https://docs.docker.com/engine/install/) or [Podman](https://podman.io/docs/installation) installed and [Helm](https://helm.sh/docs/intro/install/).

`git clone` this repository locally:

```bash
git clone https://github.com/dynatrace-perfclinics/obslab-llm-observability
cd traveladvisor
```

Create a cluster if you do not already have one:
```bash
kind create cluster --config .devcontainer/kind-cluster.yml --wait 300s
```

Customise and set some environment variables
```
export DT_ENDPOINT=https://abc12345.live.dynatrace.com
export DT_TOKEN=TODO
export OPEN_AI_TOKEN=******
```

Run the deployment script:
```bash
.devcontainer/deployment.sh
```
