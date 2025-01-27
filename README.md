# EasyTravel Bedrock - Travel Advisor

Demo application for giving travel advice written in Python. Observability signals by [OpenTelemetry](https://opentelemetry.io).

Uses [Amazon Bedrock](https://aws.amazon.com/bedrock/) to generate advice for a given destination.

> **Note**
> This product is not officially supported by Dynatrace!

### Try it yourself

* Explore our sample dashboards on the [Dynatrace Playground](https://dt-url.net/v203wj2).
* Implement AI observability in your environments with our detailed [Dynatrace Documentation](https://dt-url.net/oi23w9x).


## Configure Bedrock

You can follow the [Amazon Getting Started guide](https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started.html)
to get access to an Amazon Bedrock foundation model, or deploy your own custom model.


## Try it out yourself

[![Open "RAG" version in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new/Dynatrace/obslab-llm-observability?ref=amazon-bedrock)

## Developer Information Below

### Run Locally

You can start the application locally by running the following command.

```bash
export AWS_EMBEDDING_MODEL=<YOUR_AWS_BEDROCK_EMBEDDING_MODEL> 
export AWS_MODEL=<YOUR_AWS_BEDROCK_MODEL> 
export AWS_GUARDRAIL_ID=<OTIONAL_YOUR_AWS_BEDROCK_GUARDRAIL> 
export AWS_DEFAULT_REGION=<YOUR_AWS_REGION> 
export AWS_ACCESS_KEY_ID=<YOUR_AWS_KEY> 
export AWS_SECRET_ACCESS_KEY=<YOUR_AWS_SECRET> 
export OTEL_ENDPOINT=https://<YOUR_DT_TENANT>.live.dynatrace.com/api/v2/otlp
export API_TOKEN=<YOUR_DT_TOKEN>
python app.py
```


--------------------------

### Deploy on a Local K8S Cluster

You will need [Docker](https://docs.docker.com/engine/install/) or [Podman](https://podman.io/docs/installation) installed.


Create a cluster if you do not already have one:
```bash
kind create cluster --config .devcontainer/kind-cluster.yml --wait 300s
```

Customise and set some environment variables

```bash
export AWS_EMBEDDING_MODEL=<YOUR_AWS_BEDROCK_EMBEDDING_MODEL> 
export AWS_MODEL=<YOUR_AWS_BEDROCK_MODEL> 
export AWS_GUARDRAIL_ID=<OTIONAL_YOUR_AWS_BEDROCK_GUARDRAIL> 
export AWS_DEFAULT_REGION=<YOUR_AWS_REGION> 
export AWS_ACCESS_KEY_ID=<YOUR_AWS_KEY> 
export AWS_SECRET_ACCESS_KEY=<YOUR_AWS_SECRET>
export DT_ENDPOINT=https://<YOUR_DT_TENANT>.live.dynatrace.com
export DT_TOKEN=<YOUR_DT_TOKEN>
```

Run the deployment script:
```bash
.devcontainer/deployment.sh
```
