This demo is available in two flavours.

The "standard" demo uses OpenAI's ChatGPT (coupled with an on-cluster Weaviate cache) to look up destination advice for any destination.

The "RAG" version (available [on the rag branch](https://github.com/dynatrace-perfclinics/obslab-llm-observability/tree/rag){target="_blank"}) will **only** produce destination advice for places the system has explicitly been trained on (the files in the [destinations folder on the `rag` branch](https://github.com/dynatrace-perfclinics/obslab-llm-observability/tree/rag/destinations){target="_blank"}). Namely, `Bali` and `Sydney`.

This is achieved by:

* [Reading each file from disk when the app starts](https://github.com/dynatrace-perfclinics/obslab-llm-observability/blob/a893c0e8e93b29a0ca1b5482cb0589f9bce0b4cc/app.py#L79){target="_blank"}
* Sending the contents of the [bali and sydney HTML pages](https://github.com/dynatrace-perfclinics/obslab-llm-observability/tree/rag/destinations){target="_blank"} along with each request and [explicitly telling the model to only use the information provided in those documents](https://github.com/dynatrace-perfclinics/obslab-llm-observability/blob/a893c0e8e93b29a0ca1b5482cb0589f9bce0b4cc/app.py#L100){target="_blank"}.

The RAG version of the demo mimicks training an LLM on an internal knowledgebase.

## [>> Click here to continue with the exercise](prerequisites.md)