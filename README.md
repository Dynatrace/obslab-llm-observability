# EasyTravel GPT Travel Advisor

Demo application for giving travel advice written in Python. Observability signals by [OpenTelemetry](https://opentelemetry.io).

Uses [Ollama](https://ollama.com/) and [PineCone](https://www.pinecone.io/) to generate advice for a given destination.

You can follow the official [documentation](https://dynatr.ac/3XKxKEC) to get more insights into how it works.
Otherwise, you can explore the results using our [playground](https://dynatr.ac/4dnkuLX).


<!-- [![See a live demo](http://img.youtube.com/vi/eW2KuWFeZyY/0.jpg)](http://www.youtube.com/watch?v=eW2KuWFeZyY) -->



## Configure Pinecone

Head over to https://app.pinecone.io/ and login into your account.

1. Create a new index called `travel-advisor` with the dimensions of **3200** and a `cosine` metric.

   The index will store our knowledge source, which the RAG pipeline will use to augment the LLM's output of the travel recommendation.
   The parameter 3200 is because for this demo, we are using the embedding model `orca-mini:3b` which returns vector of 3200 elements.

   ![Pinecone Index Creation](https://dt-cdn.net/images/pinecone-index-creation-1061-dab900f5ff.png)

2. After creating and running the index, we can create an API key to connect.

   Follow the [Pinecone documentation on authentication](https://dt-url.net/ji63ugh) to get the API key to connect to your Pinecone index and store it as Kubernetes secrets with the following command:

## Try it out yourself

[![Open "RAG" version in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/dynatrace-perfclinics/obslab-llm-observability?ref=ollama-pinecone)

## Developer Information Below

### Run Locally

Start [Ollama](https://github.com/ollama/ollama) locally by running `ollama serve`. 
For this example, we'll use a simple model, `orca-mini:3b`.
You can pull it running `ollama run orca-mini:3b`.
Afterwards, you can start the application locally by running the following command.

```bash
export PINECONE_API_KEY=<YOUR_PINECONE_KEY> 
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
export PINECONE_API_KEY=<YOUR_PINECONE_KEY> 
export DT_ENDPOINT=https://<YOUR_DT_TENANT>.live.dynatrace.com
export DT_TOKEN=<YOUR_DT_TOKEN>
```

Run the deployment script:
```bash
.devcontainer/deployment.sh
```
