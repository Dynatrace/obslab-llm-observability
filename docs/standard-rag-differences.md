This demo is available in two flavours.

The "standard" demo uses OpenAI's ChatGPT (coupled with an on-cluster Weaviate cache) to look up destination advice for any destination.

The "RAG" version (available [on the rag branch](https://github.com/dynatrace-perfclinics/obslab-llm-observability/tree/rag)) will **only** produce destination advice for places the system has explicitly been trained on (the files in the [destinations folder on the `rag` branch](https://github.com/dynatrace-perfclinics/obslab-llm-observability/tree/rag/destinations)). Namely, `Bali` and `Sydney`.

The RAG version of the demo mimicks training an LLM on an internal knowledgebase.

[>> Click here to continue with the exercise](prerequisites.md)