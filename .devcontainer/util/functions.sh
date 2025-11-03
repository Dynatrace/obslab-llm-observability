#!/bin/bash
# Functions file of the codespaces framework. Functions are loaded into the shell so the user can easily call them in a dynamic fashion.
# This file contains all core functions used for deploying applications, tools or dynatrace components. 
# Brief descrition of files:
#  - functions.sh - core functions
#  - greeting.sh -zsh/bash greeting (similar to MOTD)
#  - source_framework.sh helper file to load the framework from different places (Codespaces, VSCode Extention, plain Docker container)
#  - variables.sh - variable definitions

# ======================================================================
#          ------- Util Functions -------                              #
#  A set of util functions for logging, validating and                 #
#  executing commands.                                                 #
# ======================================================================
# THis is needed when opening a terminal and the variable is not set
if [ -z "$REPO_PATH" ]; then
  export REPO_PATH="$(pwd)"
  export RepositoryName=$(basename "$REPO_PATH")
fi

# VARIABLES DECLARATION
source "$REPO_PATH/.devcontainer/util/variables.sh"

# LOAD TEST FUNCTIONS
source "$REPO_PATH/.devcontainer/test/test_functions.sh"


# FUNCTIONS DECLARATIONS
timestamp() {
  date +"[%Y-%m-%d %H:%M:%S]"
}

printInfo() {
  # The second argument defines if the log should be printed out or not
  if [ "$2" = "false" ]; then
    return 0
  fi
  echo -e "${GREEN}[$LOGNAME| ${BLUE}INFO${CYAN} |$(timestamp) ${LILA}|${RESET} $1 ${LILA}|"
}

printInfoSection() {
  if [ "$2" = "false" ]; then
    return 0
  fi
  echo -e "${GREEN}[$LOGNAME| ${BLUE}INFO${CYAN} |$(timestamp) ${LILA}|$thickline"
  echo -e "${GREEN}[$LOGNAME| ${BLUE}INFO${CYAN} |$(timestamp) ${LILA}|$halfline ${RESET}$1${LILA} $halfline"
  echo -e "${GREEN}[$LOGNAME| ${BLUE}INFO${CYAN} |$(timestamp) ${LILA}|$thinline"
}

printWarn() {
  if [ "$2" = "false" ]; then
    return 0
  fi
  echo -e "${GREEN}[$LOGNAME| ${YELLOW}WARN${GREEN} |$(timestamp) ${LILA}| ${RESET}$1${LILA}  |"
}

printError() {
  if [ "$2" = "false" ]; then
    return 0
  fi
  echo -e "${GREEN}[$LOGNAME| ${RED}ERROR${GREEN} |$(timestamp) ${LILA}| ${RESET}$1${LILA}  |"
}

postCodespaceTracker(){
  
  printInfo "Sending bizevent for $RepositoryName with $ERROR_COUNT issues built in $DURATION seconds"

  curl -X POST $ENDPOINT_CODESPACES_TRACKER \
  -H "Content-Type: application/json" \
  -H "Authorization: $CODESPACES_TRACKER_TOKEN" \
  -d "{
  \"repository\": \"$GITHUB_REPOSITORY\",
  \"repository.name\": \"$RepositoryName\",
  \"codespace.errors\": \"$ERROR_COUNT\",
  \"codespace.creation\": \"$DURATION\",
  \"codespace.type\": \"$INSTANTIATION_TYPE\",
  \"codespace.arch\": \"$ARCH\",
  \"codespace.name\": \"$CODESPACE_NAME\",
  \"environment\": \"$DT_ENVIRONMENT\",
  \"tenant\": \"$DT_TENANT\"
  }"
}

printGreeting(){
  bash $REPO_PATH/.devcontainer/util/greeting.sh
}

waitForPod() {
  # Function to filter by Namespace and POD string, default is ALL namespaces
  # If 2 parameters then the first is Namespace the second is Pod-String
  # If 1 parameters then Namespace == all-namespaces the first is Pod-String
  if [[ $# -eq 2 ]]; then
    namespace_filter="-n $1"
    pod_filter="$2"
  elif [[ $# -eq 1 ]]; then
    namespace_filter="--all-namespaces"
    pod_filter="$1"
  fi
  RETRY=0
  RETRY_MAX=60
  # Get all pods, count and invert the search for not running nor completed. Status is for deleting the last line of the output
  CMD="kubectl get pods $namespace_filter 2>&1 | grep -c -E '$pod_filter'"
  printInfo "Verifying that pods in \"$namespace_filter\" with name \"$pod_filter\" is scheduled in a workernode "
  while [[ $RETRY -lt $RETRY_MAX ]]; do
    pods_running=$(eval "$CMD")
    if [[ "$pods_running" != '0' ]]; then
      printInfo "\"$pods_running\" pods are running on \"$namespace_filter\" with name \"$pod_filter\" exiting loop."
      break
    fi
    RETRY=$(($RETRY + 1))
    printWarn "Retry: ${RETRY}/${RETRY_MAX} - No pods are running on  \"$namespace_filter\" with name \"$pod_filter\". Wait 10s for $pod_filter PoDs to be scheduled..."
    sleep 10
  done
  
  if [[ $RETRY == $RETRY_MAX ]]; then
    printError "No pods are running on  \"$namespace_filter\" with name \"$pod_filter\". Check their events. Exiting installation..."
    exit 1
  fi
}

# shellcheck disable=SC2120
waitForAllPods() {
  # Function to filter by Namespace, default is ALL
  if [[ $# -eq 1 ]]; then
    namespace_filter="-n $1"
  else
    namespace_filter="--all-namespaces"
  fi
  RETRY=0
  RETRY_MAX=60
  # Get all pods, count and invert the search for not running nor completed. Status is for deleting the last line of the output
  CMD="kubectl get pods $namespace_filter 2>&1 | grep -c -v -E '(Running|Completed|Terminating|STATUS)'"
  printInfo "Checking and wait for all pods in \"$namespace_filter\" to run."
  while [[ $RETRY -lt $RETRY_MAX ]]; do
    pods_not_ok=$(eval "$CMD")
    if [[ "$pods_not_ok" == '0' ]]; then
      printInfo "All pods are running."
      break
    fi
    RETRY=$(($RETRY + 1))
    printWarn "Retry: ${RETRY}/${RETRY_MAX} - Wait 10s for $pods_not_ok PoDs to finish or be in state Running ..."
    sleep 10
  done

  if [[ $RETRY == $RETRY_MAX ]]; then
    printError "Following pods are not still not running. Please check their events. Exiting installation..."
    kubectl get pods --field-selector=status.phase!=Running -A
    exit 1
  fi
}

waitForAllReadyPods() {
  # Function to filter by Namespace, default is ALL
  if [[ $# -eq 1 ]]; then
    namespace_filter="-n $1"
  else
    namespace_filter="--all-namespaces"
  fi
  RETRY=0
  RETRY_MAX=60
  # Get all pods, count and invert the search for not running nor completed. Status is for deleting the last line of the output
  CMD="kubectl get pods $namespace_filter 2>&1 | grep -c -v -E '(1\/1|2\/2|3\/3|4\/4|5\/5|6\/6|READY)'"
  printInfo "Checking and wait for all pods in \"$namespace_filter\" to be running and ready (max of 6 containers per pod)"
  while [[ $RETRY -lt $RETRY_MAX ]]; do
    pods_not_ok=$(eval "$CMD")
    if [[ "$pods_not_ok" == '0' ]]; then
      printInfo "All pods are running."
      break
    fi
    RETRY=$(($RETRY + 1))
    printWarn "Retry: ${RETRY}/${RETRY_MAX} - Wait 10s for $pods_not_ok PoDs to finish or be in state Ready & Running ..."
    sleep 10
  done

  if [[ $RETRY == $RETRY_MAX ]]; then
    printError "Following pods are not still not running. Please check their events. Exiting installation..."
    kubectl get pods --field-selector=status.phase!=Running -A
    exit 1
  fi
}

waitAppCanHandleRequests(){
  # Function to filter by Namespace, default is ALL
  if [[ $# -eq 1 ]]; then
    PORT="$1"
  else
    PORT="30100"
  fi
  
  RC="500"

  URL=http://localhost:$PORT
  RETRY=0
  RETRY_MAX=5
  # Get all pods, count and invert the search for not running nor completed. Status is for deleting the last line of the output
  CMD="curl --silent $URL > /dev/null"
  printInfo "Verifying that the app can handle HTTP requests on $URL"
  while [[ $RETRY -lt $RETRY_MAX ]]; do
    RESPONSE=$(eval "$CMD")
    RC=$?
    #Common RC from cURL
    #0: Success
    #6: Could not resolve host
    #7: Failed to connect to host
    #28: Operation timeout
    #35: SSL connect error
    #56:Failure with receiving network data
    if [[ "$RC" -eq 0 ]]; then
      printInfo "App is running on $URL"
      break
    fi
    RETRY=$(($RETRY + 1))
    printWarn "Retry: ${RETRY}/${RETRY_MAX} - App can't handle HTTP requests on $URL. [cURL RC:$RC] Waiting 10s..."
    sleep 10
  done

  if [[ $RETRY == $RETRY_MAX ]]; then
    printError "App is still not able to handle requests. Please check the events"
  fi
}

installHelm() {
  # https://helm.sh/docs/intro/install/#from-script
  printInfoSection " Installing Helm"
  cd /tmp
  sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  sudo chmod 700 get_helm.sh
  sudo /tmp/get_helm.sh

  printInfoSection "Helm version"
  helm version

  # https://helm.sh/docs/intro/quickstart/#initialize-a-helm-chart-repository
  printInfoSection "Helm add Bitnami repo"
  printInfoSection "helm repo add bitnami https://charts.bitnami.com/bitnami"
  helm repo add bitnami https://charts.bitnami.com/bitnami

  printInfoSection "Helm repo update"
  helm repo update

  printInfoSection "Helm search repo bitnami"
  helm search repo bitnami
}

installHelmDashboard() {

  printInfoSection "Installing Helm Dashboard"
  helm plugin install https://github.com/komodorio/helm-dashboard.git

  printInfoSection "Running Helm Dashboard"
  helm dashboard --bind=0.0.0.0 --port 8002 --no-browser --no-analytics >/dev/null 2>&1 &

}

installKubernetesDashboard() {
  # https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
  printInfoSection " Installing Kubernetes dashboard"

  helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
  helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

  # In the functions you can specify the amount of retries and the NS
  # shellcheck disable=SC2119
  waitForAllPods
  printInfoSection "kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8001:443 --address=\"0.0.0.0\", (${attempts}/${max_attempts}) sleep 10s"
  kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8001:443 --address="0.0.0.0" >/dev/null 2>&1 &
  # https://github.com/komodorio/helm-dashboard

  # Do we need this?
  printInfoSection "Create ServiceAccount and ClusterRoleBinding"
  kubectl apply -f /app/.devcontainer/etc/k3s/dashboard-adminuser.yaml
  kubectl apply -f /app/.devcontainer/etc/k3s/dashboard-rolebind.yaml

  printInfoSection "Get admin-user token"
  kubectl -n kube-system create token admin-user --duration=8760h
}

installK9s() {
  printInfoSection "Installing k9s CLI"
  curl -sS https://webinstall.dev/k9s | bash
}


setUpTerminal(){
  printInfoSection "Sourcing the DT-Enablement framework functions to the terminal, adding aliases, a Dynatrace greeting and installing power10k into .zshrc for user $USER "

  printInfoSection "Installing power10k into .zshrc for user $USER "
  
  #TODO: Verify if ohmyZsh is there so we can add this functionality to any server by loading the functions
  # source .devcontainer/util/source_framework.sh && setUpTerminal
  # or at least add ohmyzsh, power10k and no greeting
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  
  if [[ $CODESPACES == true ]]; then
    printInfoSection "Power10k configuration is limited on web. If you open the devcontainer on an IDE type 'p10k configure' to reconfigure it."
    cp $REPO_PATH/.devcontainer/p10k/.p10k.zsh.web $HOME/.p10k.zsh
  else 
    printInfoSection "Power10k configuration with many icons added."
    cp $REPO_PATH/.devcontainer/p10k/.p10k.zsh $HOME/.p10k.zsh
  fi
  
  cp $REPO_PATH/.devcontainer/p10k/.zshrc $HOME/.zshrc
  
  bindFunctionsInShell

  setupAliases

  setupMCPServer
}

setupMCPServer(){
  # Function that verifies if the .env file exists and if it contains the DT_ENVIRONMENT variable, if yes it sets it up, if not it defaults to playground.
  printInfoSection "Setting up the Dynatrace 🧠 MCP Server for VS Code"
  local environment=false
  
  # Check if .devcontainer/runlocal/.env file exists, if not then create it
  if [ ! -f "$ENV_FILE" ]; then
    printInfo ".env file not found. Creating it..."
    touch "$ENV_FILE"
    # Add default var
    setEnvironmentInEnv
  else
    printInfo ".env file already exists."
    
    while IFS= read -r line || [ -n "$line" ]; do
      # Skip empty lines and comments
      if [[ -z "$line" || "$line" =~ ^# ]]; then
        continue
      fi
      # Split the line into key and value
      IFS='=' read -r key value <<< "$line"
      # Print or process the key-value pair
      if [ "$key" = "DT_ENVIRONMENT" ]; then
          printInfo "DT_ENVIRONMENT is set to $value"
          environment=true
      fi
    done < "$ENV_FILE"

    if [ $environment = false ]; then
      setEnvironmentInEnv
    fi

  fi

  printInfo "Settings location: .vscode/mcp.json"
  printInfo "Environment variables location: $ENV_FILE"
}

selectDemoEnvironment(){
  # Check if DT_ENVIRONMENT is already set
  if [ -n "$DT_ENVIRONMENT" ]; then
    printWarn "DT_ENVIRONMENT is already set to $DT_ENVIRONMENT. This function will override the DT_ENVIRONMENT environment variable and the entry in the $ENV_FILE file."
    printf "Do you want to override it? (y/n): "
    read override
    if [ "$override" != "y" ] && [ "$override" != "Y" ]; then
      printInfo "Keeping existing DT_ENVIRONMENT. Exiting function."
      return
    fi
  fi

  printInfoSection "🧠 Please select the Environment you want to connect to:"
  printInfo "1. playground (wkf10640)"
  printInfo "2. demo.live (guu84124)"
  printInfo "3. tacocorp (bwm98081)"
  printf "Enter your choice (1-3): "
  read choice
  case $choice in
    1)
      DT_ENVIRONMENT="https://wkf10640.apps.dynatrace.com"
      ;;
    2)
      DT_ENVIRONMENT="https://guu84124.apps.dynatrace.com"
      ;;
    3)
      DT_ENVIRONMENT="https://bwm98081.apps.dynatrace.com"
      ;;
    *)
      printWarn "Invalid choice. Defaulting to playground."
      DT_ENVIRONMENT="https://wkf10640.apps.dynatrace.com"
      ;;
  esac

  export DT_ENVIRONMENT=$DT_ENVIRONMENT
  if [ -f "$ENV_FILE" ]; then
    # Remove existing DT_ENVIRONMENT line if present (including lines with leading spaces)
    sed '/^[[:space:]]*DT_ENVIRONMENT=/d' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
  fi
  echo "DT_ENVIRONMENT=$DT_ENVIRONMENT" >> "$ENV_FILE"

  printInfo "Selected Demo Environment: $DT_ENVIRONMENT"

  printInfoSection "$DT_ENVIRONMENT selected, the VS Code agent should start the MPC server automatically"
  printInfo "you can alternatively go to 'Extensions > MCP Servers installed > dynatrace-mcp-server' and start it."
  printInfo "If you want to connect to another MCP server, just type the function 'selectDemoEnvironment'"

}

setEnvironmentInEnv(){
  if [ -z "${DT_ENVIRONMENT}" ]; then
    printWarn "DT_ENVIRONMENT is missing as environment variable defaulting to playground "
    DT_ENVIRONMENT="https://wkf10640.apps.dynatrace.com"
  else
    printInfo "DT_ENVIRONMENT found as environment variable ($DT_ENVIRONMENT) and writing to file"
  fi
  echo -e "DT_ENVIRONMENT=$DT_ENVIRONMENT" >> "$ENV_FILE"
  export DT_ENVIRONMENT=$DT_ENVIRONMENT
}

bindFunctionsInShell() {
  printInfo "Binding functions.sh and adding a Greeting in the .zshrc for user $USER "
  echo "
#Making sure the Locale is set properly
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Loading all this functions in CLI
source $REPO_PATH/.devcontainer/util/functions.sh

#print greeting everytime a Terminal is opened
printGreeting

#supress p10k instant prompt
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
" >> /"$HOME"/.zshrc

}

setupAliases() {
  printInfo "Adding Bash and Kubectl Pro CLI aliases to the end of the .zshrc for user $USER "
  echo "
# Alias for ease of use of the CLI
alias las='ls -las' 
alias c='clear' 
alias hg='history | grep' 
alias h='history' 
alias gita='git add -A'
alias gitc='git commit -s -m'
alias gitp='git push'
alias gits='git status'
alias gith='git log --graph --pretty=\"%C(yellow)[%h] %C(reset)%s by %C(green)%an - %C(cyan)%ad %C(auto)%d\" --decorate --all --date=human'
alias vaml='vi -c \"set syntax:yaml\" -' 
alias vson='vi -c \"set syntax:json\" -' 
alias pg='ps -aux | grep' 
" >> /"$HOME"/.zshrc
}

installRunme() {
  printInfoSection "Installing Runme"
  mkdir runme_binary
  if [[ "$ARCH" == "x86_64" ]]; then
    printInfoSection "Installing Runme Version $RUNME_CLI_VERSION for AMD/x86"
    wget -O runme_binary/runme_linux_x86_64.tar.gz https://download.stateful.com/runme/${RUNME_CLI_VERSION}/runme_linux_x86_64.tar.gz
    tar -xvf runme_binary/runme_linux_x86_64.tar.gz --directory runme_binary
  elif [[ "$ARCH" == *"arm"* || "$ARCH" == *"aarch64"* ]]; then
    printInfoSection "Installing Runme Version $RUNME_CLI_VERSION for ARM"
    wget -O runme_binary/runme_linux_arm64.tar.gz https://download.stateful.com/runme/${RUNME_CLI_VERSION}/runme_linux_arm64.tar.gz
    tar -xvf runme_binary/runme_linux_arm64.tar.gz --directory runme_binary
  else 
    printWarn "Runme cant be installed, Architecture unknown"
  fi
  sudo mv runme_binary/runme /usr/local/bin
  rm -rf runme_binary
}

stopKindCluster(){
  printInfoSection "Stopping Kubernetes Cluster (kind-control-plane)"
  docker stop kind-control-plane 
}

startKindCluster(){
  printInfoSection "Starting Kubernetes Cluster (kind-control-plane)"
  KIND_STATUS=$(docker inspect -f '{{.State.Status}}' $KINDIMAGE 2>/dev/null)
  if [ "$KIND_STATUS" = "exited" ] || [ "$KIND_STATUS" = "dead" ]; then
    printWarn "There is a stopped $KINDIMAGE, starting it..."
    docker start $KINDIMAGE
    attachKindCluster
  elif  [ "$KIND_STATUS" = "running" ]; then
    printWarn "A $KINDIMAGE is already running, attaching to it..."
    attachKindCluster
  else
    printInfo "No $KINDIMAGE was found, creating a new one..."
    createKindCluster
  fi
  printInfo "Kind reachabe under:"
  kubectl cluster-info --context kind-kind
  printInfo "-----"
  printInfo "The following functions are available for you to maximize your K8s experience:"
  printInfo "startKindCluster - will start, create or attach to a running Cluster"
  printInfo "other useful functions: stopKindCluster createKindCluster deleteKindCluster"
  printInfo "attachKindCluster "
  printInfo "-----"
  printInfo "Setting the current context to 'kube-system' instead of 'default' you can change it by typing"
  printInfo "kubectl config set-context --current --namespace=<namespace-name>"
  kubectl config set-context --current --namespace=kube-system
}

attachKindCluster(){
  printInfoSection "Attaching to running Kubernetes Cluster (kind-control-plane)"
  local KUBEDIR="$HOME/.kube"
  if [ -d $KUBEDIR ]; then
    printWarn "Kuberconfig $KUBEDIR exists, overriding Kubernetes conection"
  else
    printInfo "Kubeconfig $KUBEDIR does not exist, creating a new one"
    mkdir -p $HOME/.kube
  fi
  kind get kubeconfig > $KUBEDIR/config && printInfo "Connection created" || printWarn "Issue creating connection"
}


createKindCluster() {
  printInfoSection "Creating Kubernetes Cluster (kind-control-plane)"
  # Create k8s cluster
  printInfo "Creating Kind cluster"
  kind create cluster --config "$REPO_PATH/.devcontainer/kind-cluster.yml" --wait 5m &&\
    printInfo "Kind cluster created successfully, reachabe under:" ||\
    printWarn "Kind cluster could not be created"
  kubectl cluster-info --context kind-kind
}

deleteKindCluster() {
  printInfoSection "Deleting Kubernetes Cluster (Kind)"
  kind delete cluster --name kind
  printInfo "Kind cluster deleted successfully."
}

certmanagerInstall() {
  printInfoSection "Install CertManager $CERTMANAGER_VERSION"
  kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v$CERTMANAGER_VERSION/cert-manager.yaml
  # shellcheck disable=SC2119
  waitForAllPods cert-manager
}

certmanagerDelete(){
  kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v$CERTMANAGER_VERSION/cert-manager.yaml
}

generateRandomEmail() {
  echo "email-$RANDOM-$RANDOM@dynatrace.ai"
}

certmanagerEnable() {
  printInfoSection "Installing ClusterIssuer with HTTP Letsencrypt "

  if [ -n "$CERTMANAGER_EMAIL" ]; then
    printInfo "Creating ClusterIssuer for $CERTMANAGER_EMAIL"
    # Simplecheck to check if the email address is valid
    if [[ $CERTMANAGER_EMAIL == *"@"* ]]; then
      echo "Email address is valid! - $CERTMANAGER_EMAIL"
      EMAIL=$CERTMANAGER_EMAIL
    else
      echo "Email address $CERTMANAGER_EMAIL is not valid. Email will be generated"
      EMAIL=$(generateRandomEmail)
    fi
  else
    echo "Email not passed.  Email will be generated"
    EMAIL=$(generateRandomEmail)
  fi

  printInfo "EmailAccount for ClusterIssuer $EMAIL, creating ClusterIssuer"
  cat $REPO_PATH/.devcontainer/yaml/clusterissuer.yaml | sed 's~email.placeholder~'"$EMAIL"'~' >$REPO_PATH/.devcontainer/yaml/gen/clusterissuer.yaml

  kubectl apply -f $REPO_PATH/.devcontainer/yaml/gen/clusterissuer.yaml

  printInfo "Let's Encrypt Process in kubectl for CertManager"
  printInfo " For observing the creation of the certificates: \n
              kubectl describe clusterissuers.cert-manager.io -A
              kubectl describe issuers.cert-manager.io -A
              kubectl describe certificates.cert-manager.io -A
              kubectl describe certificaterequests.cert-manager.io -A
              kubectl describe challenges.acme.cert-manager.io -A
              kubectl describe orders.acme.cert-manager.io -A
              kubectl get events
              "

  waitForAllPods cert-manager
  # Not needed
  #bashas "cd $K8S_PLAY_DIR/cluster-setup/resources/ingress && bash add-ssl-certificates.sh"
}

validateSaveCredentials() {
  #TODO: Refactor to evaluate variables with an indirect expansion (var name and value)
  if [[ $# -eq 3 ]]; then
    printInfo "Validating and saving Secrets DT_TENANT DT_OPERATOR_TOKEN DT_INGEST_TOKEN"
    DT_TENANT=$1
    DT_OPERATOR_TOKEN=$2
    DT_INGEST_TOKEN=$3
    #TODO: Fix this when refactoring, only printing out when return == 0 but not 1.
    verifyParseSecret $DT_TENANT true; [ $? -eq 1 ] && verifyParseSecret $DT_TENANT false || DT_TENANT=$(verifyParseSecret $DT_TENANT false)
    verifyParseSecret $DT_OPERATOR_TOKEN true; [ $? -eq 1 ] && verifyParseSecret $DT_OPERATOR_TOKEN false || DT_OPERATOR_TOKEN=$(verifyParseSecret $DT_OPERATOR_TOKEN false)
    verifyParseSecret $DT_INGEST_TOKEN true; [ $? -eq 1 ] && verifyParseSecret $DT_INGEST_TOKEN false || DT_INGEST_TOKEN=$(verifyParseSecret $DT_INGEST_TOKEN false)
    DT_OTEL_ENDPOINT=$DT_TENANT/api/v2/otlp

    kubectl delete configmap -n default dtcredentials 2>/dev/null

    kubectl create configmap -n default dtcredentials \
      --from-literal=environment=${DT_ENVIRONMENT} \
      --from-literal=tenant=${DT_TENANT} \
      --from-literal=apiToken=${DT_OPERATOR_TOKEN} \
      --from-literal=dataIngestToken=${DT_INGEST_TOKEN}
    # Exporting clean values
    export DT_ENVIRONMENT=$DT_ENVIRONMENT
    export DT_TENANT=$DT_TENANT
    export DT_OPERATOR_TOKEN=$DT_OPERATOR_TOKEN
    export DT_INGEST_TOKEN=$DT_INGEST_TOKEN
    export DT_INGEST_TOKEN=$DT_INGEST_TOKEN
    export DT_OTEL_ENDPOINT=$DT_OTEL_ENDPOINT
    return 0
  else
    printError "validateSaveCredentials function should be used like saveCredentials DT_ENVIRONMENT DT_OPERATOR_TOKEN DT_INGEST_TOKEN"
    return 1
  fi
}

verifyParseSecret(){
  # Function to verify and parse Dynatrace Tenants and tokens so they can be used more comfortably.
  # as first argument the tenant or token is passed, as second argument a boolean is passed for printing the logic. When print_log == true, then log is printed out but the 
  # variable is not echoed out, this way is not printed in the log. If print_log =0 false, then the variable is echoed out so the value can be catched as return vaue and stored.
  local secret="$1"

  local print_log="$2"
  if [ -z "$print_log" ]; then
    # As default no log is printed out. 
    print_log=false
  fi

  if [ -z "$secret" ]; then
    printError "Function to validate secrets was called but no secret was provided" $print_log
    return 1
  else 
    # Logic
    # convert apps to live
    # https://abc123.apps.dynatrace.com -> https://abc123.live.dynatrace.com 
    # remove apps from string
    # https://abc123.sprint.apps.dynatracelabs.com -> https://abc123.sprint.dynatracelabs.com 
    # https://abc123.dev.apps.dynatracelabs.com -> https://abc123.dev.dynatracelabs.com 
    # Verify if its a valid tenant
    if echo "$secret" | grep -E -q "^https:" && echo "$secret" | grep -E -q "\.dynatracelabs\.com|\.dynatrace\.com"; then
       printInfo "Valid: String starts with 'https' and contains dynatrace.com or dynatracelabs.com" $print_log
      
      # Parse Production tenants
      if echo "$secret" | grep -q "\.apps\.dynatrace\.com"; then
        printInfo "Production environment changing apps for live for API request" $print_log
        secret=$(echo "$secret" | sed 's/\.apps\.dynatrace\.com.*$/\.live.dynatrace\.com/g')
      fi
      
      # Parse for Sprint & DEV tenants
      if echo "$secret" | grep -q "\.apps\.dynatracelabs\.com"; then
        printWarn "Sprint environment removing apps for API requests" $print_log
        secret=$(echo "$secret" | sed 's/\.apps\.dynatracelabs\.com.*$/\.dynatracelabs\.com/g')
      fi
      # remove anything after .com
      if echo "$secret" | grep -q "\.com/"; then
        printWarn "/ detected after .com, invalid for API requests: removing anything after .com" $print_log
        secret=$(echo "$secret" | sed 's/\.com.*$/\.com/')
      fi
      printInfo "Tenant URL valid for API requests: $secret" $print_log
      if [ "${print_log}" = "false" ]; then
        echo "$secret"
      fi
      return 0
    elif  [[ "$secret" == dt0c01.*  && ${#secret} -gt 60 ]];  then
      printInfo "Valid Dynatrace Token format. Starts with dt0c01.XXX and has the minimum lenght." $print_log
      if [ "${print_log}" = "false" ]; then
        echo "$secret"
      fi
      return 0
    else
      printError "Invalid secret, this is not a valid dynatrace tenant nor dynatrace token, please verify this: $secret" $print_log
      return 1
    fi
  fi

}

dynatraceEvalReadSaveCredentials() {
  printInfoSection "Dynatrace evaluating and reading/saving secrets. Defined order 1.-arguments, 2.- environment variables, finally load from configmap"
  if [ "${DT_EVAL_SECRETS}" = "true" ]; then 
    printInfo "Dynatrace secrets have been evaluated already in the session. If you want to override them unset DT_EVAL_SECRETS and call this function again."
    printInfo "For printing out the secrets call the function 'printSecrets' "
    return 0
  fi

  local found=1

  if [[ $# -eq 3 ]]; then
    DT_ENVIRONMENT=$1
    DT_OPERATOR_TOKEN=$2
    DT_INGEST_TOKEN=$3
    # Passed as argument
    # We shuffle environment to tenant to modify tenant for API usage
    DT_TENANT=$DT_ENVIRONMENT
    printInfo "Secrets passed as arguments"
    validateSaveCredentials "$DT_TENANT" "$DT_OPERATOR_TOKEN" "$DT_INGEST_TOKEN"
    found=0

  elif [[ -n "${DT_ENVIRONMENT}" && -n "${DT_OPERATOR_TOKEN}" && -n "${DT_INGEST_TOKEN}" ]]; then
    # Found in env 
    printInfo "Secrets found in environment variables"

    # We shuffle environment to tenant to modify tenant for API usage
    DT_TENANT=$DT_ENVIRONMENT
    validateSaveCredentials "$DT_TENANT" "$DT_OPERATOR_TOKEN" "$DT_INGEST_TOKEN"
    found=0
  elif [[ -n "${DT_ENVIRONMENT}" ]]; then
    printWarn "Dynatrace Environment defined but tokens are missing"

    if [ -z "$DT_OPERATOR_TOKEN" ]; then
      printWarn "DT_OPERATOR_TOKEN is missing"
    fi
    
    if [ -z "$DT_INGEST_TOKEN" ]; then
      printWarn "DT_INGEST_TOKEN is missing"
    fi
    
    # We shuffle environment to tenant to modify tenant for API usage
    DT_TENANT=$DT_ENVIRONMENT
    validateSaveCredentials "$DT_TENANT" "$DT_OPERATOR_TOKEN" "$DT_INGEST_TOKEN"
    found=0
  else
    printWarn "Dynatrace secrets not found as arguments nor env vars, trying to fetch from config map"
    kubectl get configmap -n default dtcredentials 2>/dev/null
    if [[ $? -eq 0 ]]; then
      printInfo "ConfigMap found, reading from it"
      # Getting the data size
      data=$(kubectl get configmap -n default dtcredentials | awk '{print $2}')
      # parsing to number
      size=$(echo $data | grep -o '[0-9]*')
      printInfo "The Configmap has $size variables stored"
      DT_ENVIRONMENT=$(kubectl get configmap -n default dtcredentials -ojsonpath={.data.environment})
      DT_TENANT=$(kubectl get configmap -n default dtcredentials -ojsonpath={.data.tenant})
      DT_OPERATOR_TOKEN=$(kubectl get configmap -n default dtcredentials -ojsonpath={.data.apiToken})
      DT_INGEST_TOKEN=$(kubectl get configmap -n default dtcredentials -ojsonpath={.data.dataIngestToken})
      found=0
    else
        printInfo "ConfigMap not found, resetting variables"
        unset DT_ENVIRONMENT DT_TENANT DT_OPERATOR_TOKEN DT_INGEST_TOKEN
    fi

  fi

  if [[ $found -eq 0 ]]; then

    export DT_ENVIRONMENT=$DT_ENVIRONMENT
    export DT_TENANT=$DT_TENANT
    export DT_OPERATOR_TOKEN=$DT_OPERATOR_TOKEN
    export DT_INGEST_TOKEN=$DT_INGEST_TOKEN
    export DT_INGEST_TOKEN=$DT_INGEST_TOKEN
    export DT_OTEL_ENDPOINT=$DT_OTEL_ENDPOINT
    export DT_EVAL_SECRETS=true
    printSecrets
  else 
    printError "No Dynatrace secrets have been found in the environment and are needed for Dynatrace components."
    unset DT_EVAL_SECRETS
    return 1
  fi

  return $found
}

printSecrets(){
    # Print all known vars
    printInfo "Dynatrace Environment: $DT_ENVIRONMENT"
    printInfo "Dynatrace Tenant (for API): $DT_TENANT"
    printInfo "Dynatrace API & PaaS Token: ${DT_OPERATOR_TOKEN:0:14}xxx..."
    printInfo "Dynatrace Ingest Token: ${DT_INGEST_TOKEN:0:14}xxx..."
    printInfo "Dynatrace Otel API Token: ${DT_INGEST_TOKEN:0:14}xxx..."
    printInfo "Dynatrace Otel Endpoint: $DT_OTEL_ENDPOINT"
    printInfo "Secrets stored as configmap, type 'kubectl get configmap -n default dtcredentials -o json' to see them."

}

deployCloudNative() {
  dynatraceEvalReadSaveCredentials "$@"

  printInfoSection "Deploying Dynatrace in CloudNativeFullStack mode for $DT_ENVIRONMENT"
  if [ -n "${DT_TENANT}" ]; then
    # Check if the Webhook has been created and is ready
    kubectl -n dynatrace wait pod --for=condition=ready --selector=app.kubernetes.io/name=dynatrace-operator,app.kubernetes.io/component=webhook --timeout=300s

    kubectl -n dynatrace apply -f $REPO_PATH/.devcontainer/yaml/gen/dynakube-cloudnative.yaml

    printInfo "Log capturing will be handled by the Host agent."
    
    # we wait for the AG to be scheduled
    waitForPod dynatrace activegate
    
    waitForAllReadyPods dynatrace
  else
    printInfo "Not deploying the Dynatrace Operator, no credentials found"
  fi
}

deployApplicationMonitoring() { 

  dynatraceEvalReadSaveCredentials "$@"

  printInfoSection "Deploying Dynatrace in ApplicationMonitoring mode for $DT_ENVIRONMENT"
  if [ -n "${DT_TENANT}" ]; then
    # Check if the Webhook has been created and is ready
    kubectl -n dynatrace wait pod --for=condition=ready --selector=app.kubernetes.io/name=dynatrace-operator,app.kubernetes.io/component=webhook --timeout=300s

    kubectl -n dynatrace apply -f $REPO_PATH/.devcontainer/yaml/gen/dynakube-apponly.yaml
    
    # we wait for the AG to be scheduled
    waitForPod dynatrace activegate

    #FIXME: When deploying in AppOnly we need to capture the logs, either with log module or FluentBit
    #FIXME: Get log module "latest" is it possible for prod and sprint? verify
    waitForAllReadyPods dynatrace
  else
    printInfo "Not deploying the Dynatrace Operator, no credentials found"
  fi
}

undeployDynakubes() {
    printInfoSection "Undeploying Dynakubes, OneAgent installation from Workernode if installed"

    kubectl -n dynatrace delete dynakube --all
    #FIXME: Test uninstalling Dynatracem good when changing monitoring modes. 
    #kubectl -n dynatrace wait pod --for=condition=delete --selector=app.kubernetes.io/name=oneagent,app.kubernetes.io/managed-by=dynatrace-operator --timeout=300s
    sudo bash /opt/dynatrace/oneagent/agent/uninstall.sh 2>/dev/null
}

uninstallDynatrace() {
    echo "Uninstalling Dynatrace"
    undeployDynakubes

    echo "Uninstalling Dynatrace"
    helm uninstall dynatrace-operator -n dynatrace

    kubectl delete namespace dynatrace
}

# shellcheck disable=SC2120
dynatraceDeployOperator() {

  printInfoSection "Deploying Dynatrace Operator"
  # posssibility to load functions.sh and call dynatraceDeployOperator A B C to save credentials and override
  # or just run in normal deployment
  #TODO: Evaluate also Tokens and not deploy if not found.
  dynatraceEvalReadSaveCredentials "$@"
  # new lines, needed for workflow-k8s-playground, cluster in dt needs to have the name k8s-playground-{requestuser} to be able to spin up multiple instances per tenant

  if [ -n "${DT_TENANT}" ]; then
    # Deploy Operator

    deployOperatorViaHelm

    waitForAllPods dynatrace

    #FIXME: Add Ingress Nginx instrumentation and always expose in a port so all apps have RUM regardless of technology
    #printInfoSection "Instrumenting NGINX Ingress"
    #bashas "cd $K8S_PLAY_DIR/apps/nginx && bash instrument-nginx.sh"

  else
    printInfo "Not deploying the Dynatrace Operator, no credentials found"
  fi
}


generateDynakube(){
    #FIXME: This code needs to be refactored. Generate a cleaner Dynakube for both architectures. 
    # SET API URL
    API="/api"
    DT_API_URL=$DT_TENANT$API
    
    # Read the actual hostname in case changed during instalation
    CLUSTERNAME=$(hostname)
    export CLUSTERNAME

    ARM=false

    if [[ "$ARCH" == "x86_64" ]]; then
      printInfo "Codespace is running in AMD (x86_64), Dynakube image is set as default to pull the latest from the environment $DT_ENVIRONMENT"
    elif [[ "$ARCH" == *"arm"* || "$ARCH" == *"aarch64"* ]]; then
      printWarn "Codespace is running in ARM architecture ($ARCH), Dynakube image will be set in Dynakube for AG and OneAgent."
      printWarn "ActiveGate image: $AG_IMAGE"
      printWarn "OneAgent image: $OA_IMAGE"
      ARM=true
    else
      printInfo "Codespace is running on an unkown architecture ($ARCH), Dynakube image will be set in Dynakube for AG and OneAgent."
      printInfo "ActiveGate image: $AG_IMAGE"
      printInfo "OneAgent image: $OA_IMAGE"
      ARM=true
    fi

    # Generate DynaKubeSkel with API URL
    sed -e 's~apiUrl: https://ENVIRONMENTID.live.dynatrace.com/api~apiUrl: '"$DT_API_URL"'~' $REPO_PATH/.devcontainer/yaml/dynakube-skel-head.yaml > $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml

    # ClusterName for API
    sed 's~feature.dynatrace.com/automatic-kubernetes-api-monitoring-cluster-name: "CLUSTERNAME"~feature.dynatrace.com/automatic-kubernetes-api-monitoring-cluster-name: "'"$CLUSTERNAME"'"~g' $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml > $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml.tmp 

    mv $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml.tmp $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml 
    
    # Replace Networkzone
    sed 's~networkZone: CLUSTERNAME~networkZone: '$CLUSTERNAME'~g' $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml > $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml.tmp 
    
    mv $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml.tmp $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml 
    
    # Add ActiveGate config (added first so its applied to both CNFS and AppOnly)
    cat $REPO_PATH/.devcontainer/yaml/dynakube-body-activegate.yaml >> $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml
    
    # Set ActiveGate Group 
    sed 's~group: CLUSTERNAME~group: '$CLUSTERNAME'~g' $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml > $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml.tmp
    mv $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml.tmp $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml 

    if [[ $ARM == true  ]]; then
      sed 's~# image: ""~image: "'$AG_IMAGE'"~g' $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml > $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml.tmp
      mv $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml.tmp $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml 
    fi

    # Generate CloudNative Body (head + CNFS)
    cat $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml $REPO_PATH/.devcontainer/yaml/dynakube-body-cloudnative.yaml > $REPO_PATH/.devcontainer/yaml/gen/dynakube-cloudnative.yaml
    
    # Set CloudNative HostGroup
    sed 's~hostGroup: CLUSTERNAME~hostGroup: '$CLUSTERNAME'~g' $REPO_PATH/.devcontainer/yaml/gen/dynakube-cloudnative.yaml >  $REPO_PATH/.devcontainer/yaml/gen/dynakube-cloudnative.yaml.tmp
    mv  $REPO_PATH/.devcontainer/yaml/gen/dynakube-cloudnative.yaml.tmp $REPO_PATH/.devcontainer/yaml/gen/dynakube-cloudnative.yaml

    if [[ $ARM == true  ]]; then
      sed 's~# image: ""~image: "'$OA_IMAGE'"~g'  $REPO_PATH/.devcontainer/yaml/gen/dynakube-cloudnative.yaml >  $REPO_PATH/.devcontainer/yaml/gen/dynakube-cloudnative.yaml.tmp
      mv  $REPO_PATH/.devcontainer/yaml/gen/dynakube-cloudnative.yaml.tmp $REPO_PATH/.devcontainer/yaml/gen/dynakube-cloudnative.yaml
    fi
    # Generate AppOnly Body
    cat $REPO_PATH/.devcontainer/yaml/gen/dynakube-skel-head.yaml $REPO_PATH/.devcontainer/yaml/dynakube-body-apponly.yaml > $REPO_PATH/.devcontainer/yaml/gen/dynakube-apponly.yaml

}

deployOperatorViaKubectl(){

  printInfoSection "Deploying Operator via kubectl"

  kubectl create namespace dynatrace

  kubectl apply -f https://github.com/Dynatrace/dynatrace-operator/releases/download/v1.6.1/kubernetes-csi.yaml

  # Save Dynatrace Secret
  kubectl -n dynatrace create secret generic dev-container --from-literal="apiToken=$DT_OPERATOR_TOKEN" --from-literal="dataIngestToken=$DT_INGEST_TOKEN"

  generateDynakube

}

deployOperatorViaHelm(){
  helm install dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator --create-namespace --namespace dynatrace --atomic

  # Save Dynatrace Secret
  kubectl -n dynatrace create secret generic dev-container --from-literal="apiToken=$DT_OPERATOR_TOKEN" --from-literal="dataIngestToken=$DT_INGEST_TOKEN"

  generateDynakube

}

undeployOperatorViaHelm(){
  helm uninstall dynatrace-operator --namespace dynatrace
}


installMkdocs(){
  
  installRunme
  printInfo "Installing MKdocs"
  pip install --break-system-packages -r docs/requirements/requirements-mkdocs.txt
  exposeMkdocs
}


exposeMkdocs(){
  printInfo "Exposing Mkdocs in your dev.container in port 8000 & running in the background, type 'jobs' to show the process."
  nohup mkdocs serve --dev-addr=0.0.0.0:8000 --watch-theme --dirtyreload --livereload > /dev/null 2>&1 &

}


_exposeLabguide(){
  printInfo "Exposing Lab Guide in your dev.container"
  cd $REPO_PATH/lab-guide/
  nohup node bin/server.js --host 0.0.0.0 --port 3000 > /dev/null 2>&1 &
  cd -
}

_buildLabGuide(){
  printInfoSection "Building the Lab-guide in port 3000"
  cd $REPO_PATH/lab-guide/
  node bin/generator.js
  cd -
}

deployCertmanager(){
  certmanagerInstall
  certmanagerEnable
}

getNextFreeAppPort() {
  # When print_log == true, then log is printed out but the 
  # variable is not echoed out, this way is not printed in the log. If print_log =0 false, then the variable is echoed out 
  # so the value can be catched as return vaue and stored.
  local print_log="$1"
  if [ -z "$print_log" ]; then
    # As default no log is printed out. 
    print_log=false
  fi

  printInfo "Iterating over NODE_PORTS: $NODE_PORTS" $print_log

  # Reconstruct array (portable for Bash and Zsh)
  PORT_ARRAY=()
  for port in $(echo "$NODE_PORTS"); do
    PORT_ARRAY+=("$port")
  done

  for port in "${PORT_ARRAY[@]}"; do
    printInfo "Verifying if $port is free in Kubernetes Cluster..." $print_log

    # Searching for services attached to a NodePort
    allocated_app=$(kubectl get svc --all-namespaces -o wide | grep "$port")
    
    if [[ "$?" == '0' ]]; then
      printWarn "Port $port is allocated by: $allocated_app" $print_log
      app_deployed=true
    else
      printInfo "Port $port is free, allocating to app" $print_log
      if [[ $app_deployed ]]; then
        printWarn "You already have applications deployed, be careful with the sizing of your Kubernetes Cluster ;)" $print_log
      fi 
      # Use echo to return the value (functions can't use `return` for strings/numbers reliably)
      echo "$port"
      return 0
    fi
  done
  printWarn "No NodePort is free for deploying apps in your container, please delete some apps before deploying more." $print_log
  return 1
}


deployAITravelAdvisorApp(){
  printInfoSection "Deploying AI Travel Advisor App & it's LLM"
  
  if [[ "$ARCH" != "x86_64" ]]; then
    printWarn "This version of the AI Travel Advisor only supports AMD/x86 architectures and not ARM, exiting deployment..."
    return 1
  fi
  
  getNextFreeAppPort true
  PORT=$(getNextFreeAppPort)
  if [[ $? -ne 0 ]]; then
    printWarn "Application can't be deployed"
    return 1
  fi

  kubectl apply -f $REPO_PATH/.devcontainer/apps/ai-travel-advisor/k8s/namespace.yaml

  kubectl -n ai-travel-advisor create secret generic dynatrace --from-literal="token=$DT_TOKEN" --from-literal="endpoint=$DT_TENANT/api/v2/otlp"
  
  # Start OLLAMA
  printInfo "Deploying our LLM => Ollama"
  kubectl apply -f $REPO_PATH/.devcontainer/apps/ai-travel-advisor/k8s/ollama.yaml
  waitForPod ai-travel-advisor ollama
  printInfo "Waiting for Ollama to get ready"
  kubectl -n ai-travel-advisor wait --for=condition=Ready pod --all --timeout=10m
  printInfo "Ollama is ready"

  # Start Weaviate
  printInfo "Deploying our VectorDB => Weaviate"
  kubectl apply -f $REPO_PATH/.devcontainer/apps/ai-travel-advisor/k8s/weaviate.yaml

  waitForPod ai-travel-advisor weaviate
  printInfo "Waiting for Weaviate to get ready"
  kubectl -n ai-travel-advisor wait --for=condition=Ready pod --all --timeout=10m
  printInfo "Weaviate is ready"

  # Start AI Travel Advisor
  printInfo "Deploying AI App => AI Travel Advisor"
  kubectl apply -f $REPO_PATH/.devcontainer/apps/ai-travel-advisor/k8s/ai-travel-advisor.yaml
  
  waitForPod ai-travel-advisor ai-travel-advisor
  printInfo "Waiting for AI Travel Advisor to get ready"

  kubectl -n ai-travel-advisor wait --for=condition=Ready pod --all --timeout=10m
  printInfo "AI Travel Advisor is ready"

  # Define the NodePort to expose the app from the Cluster
  kubectl patch service ai-travel-advisor --namespace=ai-travel-advisor --type='json' --patch="[{\"op\": \"replace\", \"path\": \"/spec/ports/0/nodePort\", \"value\":$PORT}]"

  waitAppCanHandleRequests $PORT

  waitAppCanHandleRequests $PORT
  
  waitAppCanHandleRequests $PORT

  printInfo "AI Travel Advisor is available via NodePort=$PORT"
}

deployTodoApp(){

  printInfoSection "Deploying Todo App"

  getNextFreeAppPort true
  PORT=$(getNextFreeAppPort)
  if [[ $? -ne 0 ]]; then
    printWarn "Application can't be deployed"
    return 1
  fi

  kubectl create ns todoapp

  # Create deployment of todoApp
  kubectl -n todoapp create deploy todoapp --image=shinojosa/todoapp:1.0.1

  # Expose deployment of todoApp with a Service
  kubectl -n todoapp expose deployment todoapp --type=NodePort --name=todoapp --port=8080 --target-port=8080

  # Define the NodePort to expose the app from the Cluster
  kubectl patch service todoapp --namespace=todoapp --type='json' --patch="[{\"op\": \"replace\", \"path\": \"/spec/ports/0/nodePort\", \"value\":$PORT}]"

  waitForAllReadyPods todoapp

  waitAppCanHandleRequests $PORT

  printInfoSection "TodoApp is available via NodePort=$PORT"
}

deployAstroshop(){

  printInfoSection "Deploying Astroshop"
  
  if [[ "$ARCH" != "x86_64" ]]; then
    printWarn "This version of the Astroshop only supports AMD/x86 architectures and not ARM, exiting deployment..."
    return 1
  fi

  getNextFreeAppPort true
  PORT=$(getNextFreeAppPort)
  if [[ $? -ne 0 ]]; then
    printWarn "Application can't be deployed"
    return 1
  fi

  # Verify if cert-manager is installed in subshell to not exit function, if not, then install it
  (assertRunningPod cert-manager cert-manager >/dev/null 2>&1)
  certmanager_installed=$?
  if [[ $certmanager_installed -ne 0 ]]; then
    printWarn "Certmanager is not installed, this version of Astroshop needs it, installing it..."
    deployCertmanager
  else
    printInfo "Certmanager is installed, continuing with deployment"
  fi

  helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts

  helm dependency build $REPO_PATH/.devcontainer/apps/astroshop/helm/dt-otel-demo-helm

  kubectl create namespace astroshop

  DT_OTEL_ENDPOINT=$DT_TENANT/api/v2/otlp

  printInfo "OTEL Configuration URL $DT_OTEL_ENDPOINT and Ingest Token $DT_INGEST_TOKEN"  

  helm upgrade --install astroshop -f $REPO_PATH/.devcontainer/apps/astroshop/helm/dt-otel-demo-helm-deployments/values.yaml --set default.image.repository=docker.io/shinojosa/astroshop --set default.image.tag=1.12.0 --set collector_tenant_endpoint=$DT_OTEL_ENDPOINT --set collector_tenant_token=$DT_INGEST_TOKEN -n astroshop $REPO_PATH/.devcontainer/apps/astroshop/helm/dt-otel-demo-helm

  printInfo "Change astroshop-frontendproxy service from LoadBalancer to NodePort"
  kubectl patch service astroshop-frontendproxy --namespace=astroshop --patch='{"spec": {"type": "NodePort"}}'

  printInfo "Exposing the astroshop-frontendproxy in NodePort $PORT"
  kubectl patch service astroshop-frontendproxy --namespace=astroshop --type='json' --patch="[{\"op\": \"replace\", \"path\": \"/spec/ports/0/nodePort\", \"value\":$PORT}]"

  printInfo "Stopping all cronjobs from Demo Live since they are not needed with this scenario"
  kubectl get cronjobs -n astroshop -o json | jq -r '.items[] | .metadata.name' | xargs -I {} kubectl patch cronjob {} -n astroshop --patch '{"spec": {"suspend": true}}'

  # Listing all cronjobs
  kubectl get cronjobs -n astroshop

  waitForAllPods astroshop

  waitAppCanHandleRequests $PORT

  printInfo "Astroshop deployed succesfully and handling request in port $PORT"
}

deployBugZapperApp(){

  printInfoSection "Deploying BugZapper App"
  
  getNextFreeAppPort true
  PORT=$(getNextFreeAppPort)
  if [[ $? -ne 0 ]]; then
    printWarn "Application can't be deployed"
    return 1
  fi

  kubectl create ns bugzapper

  # Create deployment of todoApp
  kubectl -n bugzapper create deploy bugzapper --image=jhendrick/bugzapper-game:latest

  # Expose deployment of todoApp with a Service
  kubectl -n bugzapper expose deployment bugzapper --type=NodePort --name=bugzapper --port=3000 --target-port=3000

  # Define the NodePort to expose the app from the Cluster
  kubectl patch service bugzapper --namespace=bugzapper --type='json' --patch="[{\"op\": \"replace\", \"path\": \"/spec/ports/0/nodePort\", \"value\":$PORT}]"

  waitForAllReadyPods bugzapper

  waitAppCanHandleRequests $PORT

  printInfoSection "Bugzapper is available via NodePort=$PORT"
}

# deploy easytrade from manifests
deployEasyTrade() {

  printInfoSection "Deploying EasyTrade"
  
  if [[ "$ARCH" != "x86_64" ]]; then
    printWarn "This version of the EasyTrade only supports AMD/x86 architectures and not ARM, exiting deployment..."
    return 1
  fi

  getNextFreeAppPort true
  PORT=$(getNextFreeAppPort)
  if [[ $? -ne 0 ]]; then
    printWarn "Application can't be deployed"
    return 1
  fi

  # Create easytrade namespace
  printInfo "Creating 'easytrade' namespace"

  kubectl create namespace easytrade

  # Deploy easytrade manifests
  printInfo "Deploying easytrade manifests"

  kubectl apply -f $REPO_PATH/.devcontainer/apps/easytrade/manifests -n easytrade

  # Validate pods are running
  printInfo "Waiting for all pods to start"

  waitForAllPods easytrade

  printInfo "Exposing EasyTrade in your dev.container via NodePort $PORT"

  kubectl patch service frontendreverseproxy-easytrade --namespace=easytrade --type='json' --patch="[{\"op\": \"replace\", \"path\": \"/spec/ports/0/nodePort\", \"value\":$PORT}]"

  waitAppCanHandleRequests $PORT

  printInfo "EasyTrade is available via NodePort=$PORT"
}

# deploy hipstershop from manifests
deployHipsterShop() {
  
  printInfoSection "Deploying HipsterShop"
  
  if [[ "$ARCH" != "x86_64" ]]; then
    printWarn "This version of the Hipstershop only supports AMD/x86 architectures and not ARM, exiting deployment..."
    return 1
  fi

  getNextFreeAppPort true
  PORT=$(getNextFreeAppPort)
  if [[ $? -ne 0 ]]; then
    printWarn "Application can't be deployed"
    return 1
  fi

  # Create hipstershop namespace
  printInfo "Creating 'hipstershop' namespace"

  kubectl create namespace hipstershop

  # Deploy hipstershop manifests
  printInfo "Deploying hipstershop manifests"

  kubectl apply -f $REPO_PATH/.devcontainer/apps/hipstershop/manifests -n hipstershop

  # Validate pods are running
  printInfo "Waiting for all pods to start"

  waitForAllPods hipstershop

  kubectl patch service frontend-external --namespace=hipstershop --type='json' --patch="[{\"op\": \"replace\", \"path\": \"/spec/ports/0/nodePort\", \"value\":$PORT}]"

  waitAppCanHandleRequests $PORT
  
  printInfo "HipsterShop is available via NodePort=$PORT"
  
}

deployUnguard(){

  printInfoSection "Deploying Unguard"
  getNextFreeAppPort true
  PORT=$(getNextFreeAppPort)
  if [[ $? -ne 0 ]]; then
    printWarn "Application can't be deployed, all NodePorts are busy"
    return 1
  fi

  if [[ "$ARCH" != "x86_64" ]]; then
    printWarn "This version of the Unguard only supports AMD/x86 architectures and not ARM, exiting deployment..."
    return 1
  fi

  printInfo "Unguard repository https://github.com/dynatrace-oss/unguard/"

  printInfo "Adding bitnami chart ..."
  helm repo add bitnami https://charts.bitnami.com/bitnami

  printInfo "Installing unguard-mariadb ..."
  #helm install unguard-mariadb bitnami/mariadb --version 12.0.2 --set primary.persistence.enabled=false --wait --namespace unguard --create-namespace

  helm install unguard-mariadb bitnami/mariadb \
  --version 11.5.7 \
  --set primary.persistence.enabled=false \
  --set image.repository=bitnamilegacy/mariadb \
  --namespace unguard --create-namespace

  printInfo "waiting for mariadb to come online..."

  waitForAllReadyPods unguard

  printInfo "Installing Unguard"
  helm install unguard  oci://ghcr.io/dynatrace-oss/unguard/chart/unguard --version 0.12.0 --namespace unguard 

  kubectl patch service unguard-envoy-proxy --namespace=unguard --patch="{\"spec\": {\"type\": \"NodePort\", \"ports\": [{\"port\": 8080, \"nodePort\": $PORT }]}}"


}

undeployUnguard() {

  printInfoSection "Undeploying Unguard"
  helm uninstall unguard -n unguard
  helm uninstall unguard-mariadb -n unguard
  kubectl delete ns unguard --force
}


deployApp(){
  
  if [ "$#" -eq 0 ]; then
    showDeployAppUsage
    return 0
  elif [ "$#" -eq 1 ]; then
    local input="$1"
  elif [ "$#" -eq 2 ]; then
    local input="$1"
    if [[ "$2" == "-d" ]]; then
      local delete=true
    else
      printWarn "Unexpected 2nd argument"
      showDeployAppUsage
      return 1
    fi
  else
    printWarn "Unexpected number of arguments"
    showDeployAppUsage
    return 1
  fi

  case "$input" in
    1 | a | ai-travel-advisor)
      if [[ $delete ]]; then
        printInfoSection "Undeploying ai-travel-advisor..."
        kubectl delete ns ai-travel-advisor --force
      else
        deployAITravelAdvisorApp
      fi
      ;;

    2 | b | astroshop)
      if [[ $delete ]]; then
        printInfoSection "Undeploying astroshop..."
        kubectl delete ns astroshop --force
        certmanagerDelete
      else
        deployAstroshop
      fi
      ;;

    3 | c | bugzapper)
       if [[ $delete ]]; then
        printInfo "Undeploying bugzapper..."
        kubectl delete ns bugzapper --force
      else
        deployBugZapperApp
      fi
      ;;

    4 | d | easytrade)
       if [[ $delete ]]; then
        printInfo "Undeploying easytrade..."
        kubectl delete ns easytrade --force
      else
        deployEasyTrade
      fi
      ;;

    5 | e | hipstershop)
       if [[ $delete ]]; then
        printInfo "Undeploying hipstershop..."
        kubectl delete ns hipstershop --force
      else
        deployHipsterShop
      fi
      ;;

    6 | f | todoapp)
       if [[ $delete ]]; then
        printInfo "Undeploying todoapp..."
        kubectl delete ns todoapp --force
      else
        deployTodoApp
      fi
      ;;

    7 | g | unguard)
       if [[ $delete ]]; then
        printInfo "Undeploying unguard..."
        undeployUnguard
      else
        deployUnguard
      fi
      ;;

    *)
      printWarn "Invalid selection: '$input'. Please choose a valid app identifier."
      showDeployAppUsage
      return 1
      ;;
  esac
  return 0
}

showDeployAppUsage(){
  printInfoSection "   Un/Deploy an Application to your Kubernetes Cluster      "
  printInfo "                ${PACKAGE} Application repository  ${PACKAGE}                               "
  printInfo "                                                                            "
  printInfo "For deploying one of the following apps, type the number, character or name "
  printInfo "associated e.g. for astroshop type deployApp '2', 'b' or 'astroshop'        "
  printInfo "                                                                            "
  printInfo "For undeploying an app, type -d as an extra argument                        "
  printInfo "----------------------------------------------------------------------------"
  printInfo "[#]  [c]  [ name ]             AMD     ARM                                  "
  printInfo "[1]   a   ai-travel-advisor     +       -                                   "
  printInfo "[2]   b   astroshop             +       -                                   "
  printInfo "[3]   c   bugzapper             +       +                                   "
  printInfo "[4]   d   easytrade             +       -                                   "
  printInfo "[5]   e   hipstershop           +       -                                   "
  printInfo "[6]   f   todoapp               +       +                                   "
  printInfo "[7]   g   unguard               +       -                                   "
  printInfo "----------------------------------------------------------------------------"
}

deleteCodespace(){
  printWarn "Warning! Codespace $CODESPACE_NAME will be deleted, the connection will be lost in a sec... " 
  gh codespace delete --codespace "$CODESPACE_NAME" --force
}


showOpenPorts(){
  sudo netstat -tulnp
  # another alternative is 
  # sudo ss -tulnp
}

deployGhdocs(){
  mkdocs gh-deploy
}

getRunningDockerContainernameByImagePattern(){
  pattern=$1

  containername=$(docker ps --filter "status=running" --format "{{.Names}} {{.Image}}" | grep $pattern | awk '{print $1}')

  echo $containername

}

verifyCodespaceCreation(){
  printInfoSection "Verify Codespace creation"
  #TODO Enhance this function and send (part) of the error to the monitoring service
  calculateTime
  if [[ $INSTANTIATION_TYPE == "github-codespaces" ]]; then
    CODESPACE_ERRORS=$(cat $CODESPACE_PSHARE_FOLDER/creation.log | grep -i -E 'error|failed')
  elif [[ $INSTANTIATION_TYPE == "remote-container" ]] || [[ $INSTANTIATION_TYPE == "github-workflow" ]]; then
    #FIXME: Verify instantiation of Github Actions & VS Code Remote containers
    containername=$(getRunningDockerContainernameByImagePattern "vsc")
    
    CODESPACE_ERRORS=$(docker logs $containername | grep -i -E 'error|failed')
    # Print logs of VSCode and cat grep them.
    printWarn "Container was created in a remote container, either VS Code or Github Actions. Verification of proper creation TBD"
  elif [[ $INSTANTIATION_TYPE == "local-docker-container" ]]; then
    containername=$(getRunningDockerContainernameByImagePattern "dt-enablement")
    CODESPACE_ERRORS=$(docker logs $containername | grep -i -E 'error|failed')
    # above method works only calling it the first time. Otherwise the erros will be multiplied. We could clean them like below:
    #awk '/Verify Codespace creation/ {exit} {print}' /tmp/dt-enablement.log > /tmp/dt-enablement-create.log
  else 
    printWarn "Container creation unknown."
  fi

  if [ -n "$CODESPACE_ERRORS" ]; then
      ERROR_COUNT=$(printf "%s" "$CODESPACE_ERRORS" | wc -l) 
  else
      ERROR_COUNT=0
  fi
  printInfo "$ERROR_COUNT issues detected in the creation of the codespace: $CODESPACE_ERRORS" 

  export CODESPACE_ERRORS
  updateEnvVariable ERROR_COUNT
 
}

calculateTime(){
  # Read from file
  if [ -e "$COUNT_FILE" ]; then
    source $COUNT_FILE
  fi
  # if equal 0 then set duration and update file
  if [ "$DURATION" -eq 0 ]; then 
    DURATION="$SECONDS"
    updateEnvVariable DURATION
  fi
  printInfo "It took $(($DURATION / 60)) minutes and $(($DURATION % 60)) seconds the post-creation of the codespace."
}

updateEnvVariable(){
  local variable="$1"
  # Checking the process name (zsh/bash)
  if [[ "$(ps -p $$ -o comm=)" == "zsh" ]]; then
    #printInfo "ZSH"
    #printInfo "update [$variable:${(P)variable}]"
    # indirect variable expansion in ZSH
    # shellcheck disable=SC2296
    sed "s|^$variable=.*|$variable=${(P)variable}|" $COUNT_FILE > $COUNT_FILE.tmp
    mv $COUNT_FILE.tmp $COUNT_FILE
  else
    #printInfo "BASH"
    #printInfo "update [$variable:${!variable}]"
    # indirect variable expansion in BASH
    sed "s|^$variable=.*|$variable=${!variable}|" $COUNT_FILE  > $COUNT_FILE.tmp
    mv $COUNT_FILE.tmp $COUNT_FILE
  fi
  
  export $variable
}

finalizePostCreation(){
  # e2e testing
  # If the codespace is created (eg. via a Dynatrace workflow)
  # and hardcoded to have a name starting with dttest-bash b
  # Then run the e2e test harness
  # Otherwise, send the startup ping
  if [[ "$CODESPACE_NAME" == dttest-* ]]; then
      # Set default repository for gh CLI
      gh repo set-default "$GITHUB_REPOSITORY"

      # Set up a label, used if / when the e2e test fails
      # This may already be set, so catch error and always return true
      gh label create "e2e test failed" --force || true

      # Install required Python packages
      pip install -r "$REPO_PATH/.devcontainer/testing/requirements.txt" --break-system-packages

      # Run the test harness script
      python "$REPO_PATH/.devcontainer/testing/testharness.py"

      # Testing finished. Destroy the codespace
      gh codespace delete --codespace "$CODESPACE_NAME" --force
  else
      
      verifyCodespaceCreation
      postCodespaceTracker
  fi
}


runIntegrationTests(){
  #this function will trigger the integration Tests for this repo.
  bash "$REPO_PATH/.devcontainer/test/integration.sh"
}

calculateReadingTime(){
  
  printInfoSection "Calculating the reading time of the Documentation"
  DOCS_DIR="/docs"
  WORDS_PER_MIN=200
  total_words=0
  total_mins=0

  printInfo "Section \t\t| Words \t| Estimated Reading Time (min)"
  printInfo "--------\t\t|-------\t|-----------------------------"
  find "$REPO_PATH/$DOCS_DIR" -type f -name "*.md" | while read -r file; do
      section=$(basename "$file")
      words=$(wc -w < "$file")
      # Calculate reading time, rounding up
      mins=$(( (words + WORDS_PER_MIN - 1) / WORDS_PER_MIN ))
      total_words=$((total_words + words))
      total_mins=$((total_mins + mins))

      printInfo "$section \t\t| $words \t| $mins min"
  done
  
  printInfo "---------------------------------------------"
  printInfo "TOTAL     | $total_words | $total_mins min"

}

checkHost(){

  printInfoSection "Verifying Host requirements"
  make_available=false
  docker_available=false
  docker_accessible=false
  node_available=false
  npm_available=false
  #TODO: Check that the files can be modified, needed for the docker user to write in the volume mount, test @ignacio.goldman setup.

  # Check if host is Ubuntu
  if grep -qi ubuntu /etc/os-release; then
    printInfo "✅ Ubuntu detected"
  else
    printWarn "⚠️ Not Ubuntu, we can't guarantee proper functioning"
  fi

  # Check if make is installed
  if command -v make >/dev/null; then
    printInfo "✅ make is installed (version: $(make --version))"
    make_available=true
  else
    printWarn "❌ make is NOT installed"
    make_available=false
  fi

  # Check if docker is installed
  if command -v docker >/dev/null; then
    printInfo "✅ docker is installed (version: $(docker --version))"
    docker_available=true
  else
    printWarn "❌ docker is NOT installed"
    docker_available=false
  fi

  # Check if user has access to docker
  if docker info >/dev/null 2>&1; then
    printInfo "✅ Docker is accessible"
    docker_accessible=true
  else
    printWarn "❌ No access to Docker"
    docker_accessible=false
  fi

  # Check if node is installed
  if command -v node >/dev/null; then
    printInfo "✅ node is installed (version: $(node --version))"
    node_available=true
  else
    printWarn "❌ node is NOT installed (needed for Dynatrace MCP Server)"
    node_available=false
  fi

  # Check if npm is installed
  if command -v npm >/dev/null; then
    printInfo "✅ npm is installed (version: $(npm --version)) "
    npm_available=true
  else
    printWarn "❌ npm is NOT installed (needed for MCP Server)"
    npm_available=false
  fi

  # Prompt if any requirement is missing
  if [ "$make_available" = false ] || [ "$docker_available" = false ] || [ "$docker_accessible" = false ] || [ "$node_available" = false ] || [ "$npm_available" = false ]; then
    printWarn "One or more requirements are missing or not accessible"
    printWarn "Would you like to attempt to correct them now? (y/n) 'yes' to run the commands for you, 'n' we only print how to resolve the issue"
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      # Install make if missing
      if [ "$make_available" = false ]; then
        printInfo "Installing make..."
        sudo apt-get update && sudo apt-get install -y make
      fi
      # Install docker if missing
      if [ "$docker_available" = false ]; then
        printInfo "Installing docker..."
        sudo apt-get update && sudo apt-get install -y docker.io
        sudo systemctl enable --now docker
      fi
      # Add user to docker group if docker not accessible
      if [ "$docker_accessible" = false ]; then
        printInfo "Adding user $USER to docker group and restarting docker..."
        sudo usermod -aG docker $USER
        sudo systemctl restart docker
        printWarn "You may need to log out and log back in for group changes to take effect."
      fi
      # Install node if missing
      if [ "$node_available" = false ]; then
        printInfo "Installing nodejs..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash - \
          && sudo apt-get install -y nodejs 
      fi
      # Install npm if missing
      if [ "$npm_available" = false ]; then
        printInfo "Installing npm..."
        sudo npm install -g npm@latest  && sudo rm -rf /var/lib/apt/lists/*
      fi
      printInfo "Auto-fix attempted. Please re-run this function or open a new shell."
    else
      printWarn "Host setup not corrected. Some features may not work as expected."
      if [ "$make_available" = false ]; then
        printInfo "To install make: sudo apt-get update && sudo apt-get install -y make"
      fi
      if [ "$docker_available" = false ]; then
        printInfo "To install docker: sudo apt-get update && sudo apt-get install -y docker.io && sudo systemctl enable --now docker"
      fi
      if [ "$docker_accessible" = false ]; then
        printInfo "To enable Docker access: sudo usermod -aG docker $USER && sudo systemctl restart docker (then log out and back in)"
      fi
      if [ "$node_available" = false ]; then
        printInfo "To install nodejs: sudo apt-get update && sudo apt-get install -y nodejs"
      fi
      if [ "$npm_available" = false ]; then
        printInfo "To install npm: sudo apt-get update && sudo apt-get install -y npm"
      fi
    fi
  else
    printInfo "✅ All requirements are met for running the enablement-framework. Navigate to the .devcontainer/ folder then 'make start' to start your enablement jouney 🚀"
  fi

}

# Custom functions for each repo can be added in my_functions.sh
source $REPO_PATH/.devcontainer/util/my_functions.sh
