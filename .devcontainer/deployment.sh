#!/usr/bin/env bash

kubectl create namespace travel-advisor

# Create secrets
kubectl -n travel-advisor create secret generic pinecone --from-literal=api-key=$PINECONE_API_KEY
kubectl -n travel-advisor create secret generic dynatrace --from-literal=token=$DT_TOKEN --from-literal=endpoint=$DT_ENDPOINT/api/v2/otlp

# Deploy ollama
kubectl apply -f deployment/ollama.yaml -n ollama
echo "Waiting for Ollama to be ready"

# Wait
kubectl -n ollama wait --for=condition=Ready pod --all --timeout=10m

# Deploy the application
kubectl apply -f deployment/travel-advisor.yaml -n travel-advisor

# Wait for travel advisor system to be ready
echo "Waiting for Travel Advisor to be ready"
kubectl -n travel-advisor wait --for=condition=Ready pod --all --timeout=10m
