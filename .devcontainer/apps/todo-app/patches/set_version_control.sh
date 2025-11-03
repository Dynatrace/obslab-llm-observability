#!/bin/bash

# Small bash script for patching deployments via kubectl, more information about integrating the live debugger with your version control see: 
# https://docs.dynatrace.com/docs/observe/applications-and-microservices/developer-observability/offering-capabilities/additional-settings#integrate-with-your-version-control

# Variable definition
version="v1.0.0"
deployment="todoapp"
container="todoapp"
namespace="todoapp"

DT_LIVEDEBUGGER_COMMIT=""
DT_LIVEDEBUGGER_REMOTE_ORIGIN=""


set_version_control_information(){
    DT_LIVEDEBUGGER_REMOTE_ORIGIN=$(git remote get-url origin)
    DT_LIVEDEBUGGER_COMMIT=$(git rev-parse $version)

    echo "Fetching git revision for $version in $DT_LIVEDEBUGGER_REMOTE_ORIGIN" 
    echo $DT_LIVEDEBUGGER_COMMIT

    export DT_LIVEDEBUGGER_REMOTE_ORIGIN=$DT_LIVEDEBUGGER_REMOTE_ORIGIN
    export DT_LIVEDEBUGGER_COMMIT=$DT_LIVEDEBUGGER_COMMIT
}


patch_deployment(){ 
kubectl patch deployment $deployment -n $namespace -p "$(cat <<EOF
{
    "spec": {
        "template": {
            "spec": {
                "containers": [
                    {
                        "name": "$container",
                        "env": [
                            {
                                "name": "DT_LIVEDEBUGGER_COMMIT",
                                "value": "$DT_LIVEDEBUGGER_COMMIT"
                            },
                            {
                                "name": "DT_LIVEDEBUGGER_REMOTE_ORIGIN",
                                "value": "$DT_LIVEDEBUGGER_REMOTE_ORIGIN"
                            }
                        ]
                    }
                ]
            }
        }
    }
}
EOF
)"
}

set_version_control_information
patch_deployment