--8<-- "snippets/index.js"

--8<-- "snippets/disclaimer.md"

## What's this tutorial all about
In this tutorial we'll learn the basics about AI & LLM Monitoring.

Dynatrace supports [AI and LLM Observability](https://docs.dynatrace.com/docs/analyze-explore-automate/dynatrace-for-ai-observability#ai-and-llm-observability)
for more than 40 different technologies providing visibility into the different layers of AI and LLM applications.

- Monitor service health and performance: Track real-time metrics (request counts, durations, and error rates). Stay aligned with SLOs.
- Monitor service quality and cost: Implement error budgets for performance and cost control. Validate model consumption and response times. Prevent quality degradation by monitoring models and usage patterns in real time.
- End-to-end tracing and debugging: Trace prompt flows from initial request to final response for quick root cause analysis and troubleshoot. Gain granular visibility into LLM prompt latencies and model-level metrics. Pinpoint issues in prompts, tokens, or system integrations.
- Build trust, reduce compliance and audit risks: Track every input and output for an audit trail. Query all data in real time and store for future reference. Maintain full data lineage from prompt to response.


!!! tip "What will we do"
    In this tutorial we will learn how it is easy to observe an AI application that uses [Ollama](https://ollama.com/)
    as Large Language Model, [Weaviate](https://weaviate.io/) as Vector Database, and [LangChain](https://www.langchain.com/) as an orchestrator
    to create [Retrieval augmented generation (RAG)](https://python.langchain.com/docs/concepts/rag/) and [Agentic](https://python.langchain.com/docs/concepts/agents/) AI Pipelines.

<div class="grid cards" markdown>
- [Yes! let's begin :octicons-arrow-right-24:](2-getting-started.md)