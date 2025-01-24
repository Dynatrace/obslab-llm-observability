#!/usr/bin/env bash

kubectl create namespace travel-advisor

# Create secrets
kubectl -n travel-advisor create secret generic bedrock \
  --from-literal=region=$AWS_DEFAULT_REGION \
  --from-literal=key=$AWS_ACCESS_KEY_ID \
  --from-literal=secret=$AWS_SECRET_ACCESS_KEY \
  --from-literal=embedding=$AWS_EMBEDDING_MODEL \
  --from-literal=model=$AWS_MODEL \
  --from-literal=guardrail=$AWS_GUARDRAIL_ID

kubectl -n travel-advisor create secret generic dynatrace --from-literal=token=$DT_TOKEN --from-literal=endpoint=$DT_ENDPOINT/api/v2/otlp

# Deploy the application
kubectl apply -f deployment/travel-advisor.yaml -n travel-advisor

# Wait for travel advisor system to be ready
echo "Waiting for Travel Advisor to be ready"
kubectl -n travel-advisor wait --for=condition=Ready pod --all --timeout=10m
