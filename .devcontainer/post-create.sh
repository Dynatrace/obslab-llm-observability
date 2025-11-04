#!/bin/bash
#loading functions to script
export SECONDS=0
source .devcontainer/util/source_framework.sh

setUpTerminal

startKindCluster

installK9s

#installMkdocs


# Dynatrace Operator can be deployed automatically
#dynatraceDeployOperator

# You can deploy CNFS or AppOnly
#deployCloudNative
#deployApplicationMonitoring

# In here you deploy the Application you want
# The TODO App will be deployed as a sample
#deployTodoApp
deployAITravelAdvisorApp

# The Astroshop keeping changes of demo.live needs certmanagerdocker
#certmanagerInstall
#certmanagerEnable
#deployAstroshop

# If you want to deploy your own App, just create a function in the functions.sh file and call it here.
# deployMyCustomApp

# If the Codespace was created via Workflow end2end test will be done, otherwise
# it'll verify if there are error in the logs and will show them in the greeting as well a monitoring 
# notification will be sent on the instantiation details
finalizePostCreation

printInfoSection "Your dev container finished creating"
