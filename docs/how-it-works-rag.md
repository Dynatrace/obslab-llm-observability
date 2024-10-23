
The "Retrieval-Augmented Generation" (RAG) version (available [on the ollama-pinecone branch](https://github.com/dynatrace-perfclinics/obslab-llm-observability/tree/ollama-pinecone){target="_blank"}) mimicks training an LLM on an internal knowledgebase. 
It will produce custom destination advice for places the system has explicitly been trained on (the files in the [destinations folder](https://github.com/dynatrace-perfclinics/obslab-llm-observability/tree/ollama-pinecone/destinations){target="_blank"}).
Namely, `Bali` and `Sydney`. For other locations, the model will provide an answer based on its own knowledge.
It is based on [Ollama](https://dt-url.net/l843uge) and uses [PineCone](https://dt-url.net/0323urx) as a Vector database. The RAG pipeline is built using [LangChain](https://dt-url.net/6d03u7j). 

The RAG version of the demo mimicks training an LLM on an internal knowledgebase.

![](https://dt-cdn.net/images/architecture-rag-1269-e11f226cf6.jpg)

When the application starts, files inside the [destinations](https://github.com/dynatrace-perfclinics/obslab-llm-observability/tree/ollama-pinecone/destinations){target="_blank"} folder are read, processed, and stored in PineCone for later lookup.
Afterwards, each request goes through the LangChain RAG pipeline, which performs the following steps:

* It contacts Ollama to produce an embedding of the user input
* With the embedding, reach out to PineCone to find documents relevant to the user input
* Use the documents to perform prompt engineering and send it to Ollama to produce the travel recommendation 
* Process the answer received 

<div class="grid cards" markdown>
- [Click Here to Continue :octicons-arrow-right-24:](prerequisites.md)
</div>
