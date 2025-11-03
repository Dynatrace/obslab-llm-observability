#!/bin/bash
# Here is the definition of the test functions, the file needs to be loaded within the functions.sh file

assertDynatraceOperator(){

    printInfoSection "Testing Dynatrace Operator Deployment"
    kubectl get all -n dynatrace
    printWarn "TBD"
}

assertDynatraceCloudNative(){
    printInfoSection "Testing Dynatrace CloudNative FullStack deployment"
    kubectl get all -n dynatrace
    kubectl get dynakube -n dynatrace
    printWarn "TBD"
}

assertRunningApp(){
  # The 1st agument is the port.
  if [ -z "$1" ]; then
    PORT=30100
  else
    PORT=$1
  fi
    
  URL="http://127.0.0.1:$PORT"
  printInfoSection "Testing Deployed app running in $URL"

  printInfo "Asserting app is running as NodePort in kind-control-plane in port $URL"

  if docker exec kind-control-plane sh -c "curl --silent --fail $URL" > /dev/null; then
    printInfo "✅ App is running on $URL"
  else
    printError "❌ App is NOT running on $URL"
    exit 1
  fi
}

getVscodeContainername(){
    docker ps --format '{{json .}}' | jq -s '.[] | select(.Image | contains("vsc")) | .Names'
    containername=$(docker ps --format '{{json .}}' | jq -s '.[] | select(.Image | contains("vsc")) | .Names')
    containername=${containername//\"/}
    echo "$containername"
}

assertRunningPod(){

  printInfoSection "Asserting running pods in namespace '$1' that contain the name '$2'"
  # Function to filter by Namespace and POD string, default is ALL namespaces
  # If 2 parameters then the first is Namespace the second is Pod-String
  # If 1 parameters then Namespace == all-namespaces the first is Pod-String
  if [[ $# -eq 2 ]]; then
    namespace_filter="-n $1"
    pod_filter="$2"
    verify_namespace=true
  elif [[ $# -eq 1 ]]; then
    namespace_filter="--all-namespaces"
    pod_filter="$1"
  fi

  # Need to check if the NS exists
  if [[ $verify_namespace == true ]]; then
    kubectl get namespace "$1" >/dev/null 2>&1
    if [[ $? -eq 1 ]]; then
      printError "❌ Namespace \"$1\" does not exists."
      exit 1
    fi
  fi

  # Get all pods, count and invert the search for not running nor completed. Status is for deleting the last line of the output
  CMD="kubectl get pods $namespace_filter 2>&1 | grep -c -E '$pod_filter'"
  printInfo "Verifying that pods in \"$namespace_filter\" with name \"$pod_filter\" are up and running."
  pods_running=$(eval "$CMD")
  
  if [[ "$pods_running" != '0' ]]; then
      printInfo "✅ \"$pods_running\" pods are running on \"$namespace_filter\" with name \"$pod_filter\"."    
  else 
      printError "❌ \"$pods_running\" pods are running on \"$namespace_filter\" with name \"$pod_filter\". "
      kubectl get pods $namespace_filter
      exit 1
  fi
}

assertDynakube(){
    printInfoSection "Verifying Dynakube is deployed and running"

}