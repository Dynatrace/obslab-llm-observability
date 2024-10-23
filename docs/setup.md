## Create OpenAI API Token

Go to [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys){target="_blank"} and create a new API Key.

## Format Dynatrace URL

Make a note of your Dynatrace URL, it should be in the following format:

```
https://ENVIRONMENT-ID.live.dynatrace.com
```

For example:

```
https://abc12345.live.dynatrace.com
```

## Create Dynatrace Token

In Dynatrace, press `Ctrl + k` and search for `access tokens`. Choose the first option.

### DT_API_TOKEN

Create an API token with these permissions:

- Ingest metrics (`metrics.ingest`)
- Ingest logs (`logs.ingest`)
- Ingest events (`events.ingest`)
- Ingest OpenTelemetry traces  (`openTelemetryTrace.ingest`)
- Read metrics (`metrics.read`)
- Write settings  (`settings.write`)

This token will be used by the OpenTelemetry collector and k6 to send data to Dynatrace.
The setup script which runs automatically when the codespace is created also uses this to [configure span attribute capture rules in Dynatrace](https://github.com/dynatrace-perfclinics/obslab-llm-observability/blob/82cedeac2bbe2a6e59c5a94f8a798ff81e204660/.devcontainer/deployment.sh#L5){target="_blank"}
this means the relevant OpenTelemetry span attributes will automatically be stored.

## 🔁 Recap

You should now have `3` pieces of information:

- The `DT_ENDPOINT` (eg. `https://abc12345.live.dynatrace`)
- The `DT_API_TOKEN`
- The `OPEN_AI_TOKEN`

When you have these pieces of information, you can proceed.

<div class="grid cards" markdown>
- [Click Here to Continue :octicons-arrow-right-24:](startup.md)
</div>