#!/bin/bash +x
 # Read the domain from CM
#source ../util/loaddomain.sh

# Load the functions
# Read the variables
#source ../../cluster-setup/functions.sh
#source ../../cluster-setup/resources/dynatrace/credentials.sh

printInfoSection "Deploying Astroshop"

# read the credentials and variables
saveReadCredentials 

###
# Instructions to install Astroshop with Helm Chart from R&D and images built in shinojos repo (including code modifications from R&D)
####
sed 's~domain.placeholder~'"$DOMAIN"'~' $REPO_PATH/.devcontainer/astroshop/helm/dt-otel-demo-helm/values.yaml > $REPO_PATH/.devcontainer/astroshop/helm/dt-otel-demo-helm/values.yaml.tmp
mv $REPO_PATH/.devcontainer/astroshop/helm/dt-otel-demo-helm/values.yaml.tmp $REPO_PATH/.devcontainer/astroshop/helm/dt-otel-demo-helm/values.yaml

sed 's~domain.placeholder~'"$DOMAIN"'~' $REPO_PATH/.devcontainer/astroshop/helm/dt-otel-demo-helm-deployments/values.yaml > $REPO_PATH/.devcontainer/astroshop/helm/dt-otel-demo-helm-deployments/values.yaml.tmp
mv $REPO_PATH/.devcontainer/astroshop/helm/dt-otel-demo-helm-deployments/values.yaml.tmp $REPO_PATH/.devcontainer/astroshop/helm/dt-otel-demo-helm-deployments/values.yaml

helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

helm dependency build $REPO_PATH/.devcontainer/astroshop/helm/dt-otel-demo-helm

kubectl create namespace astroshop

echo "OTEL Configuration URL $DT_OTEL_ENDPOINT and Token $DT_INGEST_TOKEN"  

helm upgrade --install astroshop -f .$REPO_PATH/.devcontainer/astroshop/helm/dt-otel-demo-helm-deployments/values.yaml --set default.image.repository=docker.io/shinojosa/astroshop --set default.image.tag=1.12.0 --set collector_tenant_endpoint=$DT_OTEL_ENDPOINT --set collector_tenant_token=$DT_INGEST_TOKEN -n astroshop ./helm/dt-otel-demo-helm

printInfo "Stopping all cronjobs from Demo Live since they are not needed with this scenario"

kubectl get cronjobs -n astroshop -o json | jq -r '.items[] | .metadata.name' | xargs -I {} kubectl patch cronjob {} -n astroshop --patch '{"spec": {"suspend": true}}'

kubectl get cronjobs -n astroshop

printInfo "Astroshop available at: "

kubectl get ing -n astroshop