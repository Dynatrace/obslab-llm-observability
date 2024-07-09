#!/usr/bin/env bash

kubectl create namespace travel-advisor

# Capture OpenTelemetry Span Attributes
curl -X 'POST' \
  "$DT_ENDPOINT/api/v2/settings/objects?validateOnly=false" \
  -H 'accept: application/json; charset=utf-8' \
  -H "Authorization: Api-Token $DT_TOKEN" \
  -H 'Content-Type: application/json; charset=utf-8' \
  -d '[ {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.request.model"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.system"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.request.max_tokens"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.request.temperature"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.request.top_p"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.response.finish_reasons"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.response.id"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.response.model"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.usage.completion_tokens"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.usage.prompt_tokens"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.prompt.0.content"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "llm.headers"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "llm.is_streaming"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "llm.request.type"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "llm.usage.total_tokens"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "openai.api_base"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "db.operation"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "db.system"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "db.weaviate.query.get.class_name"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "db.weaviate.query.get.properties"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.completion.0.content"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.completion.0.finish_reason"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.completion.0.role"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.prompt.0.content"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "gen_ai.prompt.0.role"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "weaviate.data.crud_data.create.class_name"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "weaviate.data.crud_data.create.data_object"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "traceloop.entity.input"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "traceloop.entity.name"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "traceloop.entity.output"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "traceloop.span.kind"
          }
        }, {
          "schemaId": "builtin:attribute-allow-list",
          "schemaVersion": "0.0.10",
          "scope": "environment",
          "value": {
            "enabled": true,
            "key": "traceloop.workflow.name"
          }
        }
      ]'

# Create secret for k6 to use
kubectl -n travel-advisor create secret generic dt-details --from-literal=DT_ENDPOINT=$DT_ENDPOINT --from-literal=DT_API_TOKEN=$DT_TOKEN

kubectl create secret generic dynatrace-otelcol-dt-api-credentials \
  --from-literal=DT_ENDPOINT=$DT_ENDPOINT \
  --from-literal=DT_API_TOKEN=$DT_TOKEN

kubectl create secret generic openai-details -n travel-advisor \
  --from-literal=API_KEY=$OPEN_AI_TOKEN

# Install Dynatrace supported distribution of the OpenTelemetry collector
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade -i dynatrace-collector open-telemetry/opentelemetry-collector -f collector-values.yaml --wait

# Deploy the application
kubectl apply -f deployment/deployment.yaml -n travel-advisor

# Wait for travel advisor system to be ready
kubectl -n travel-advisor wait --for=condition=Ready pod --all --timeout=10m