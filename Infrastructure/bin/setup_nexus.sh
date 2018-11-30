#!/bin/bash
# Setup Nexus Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
NEXUS_PROJECT=${GUID}-nexus3
echo "Setting up Nexus in project $GUID-nexus"

# Code to set up the Nexus. It will need to
# * Create Nexus
# * Set the right options for the Nexus Deployment Config
# * Load Nexus with the right repos
# * Configure Nexus as a docker registry
# Hint: Make sure to wait until Nexus if fully up and running
#       before configuring nexus with repositories.
#       You could use the following code:
# while : ; do
#   echo "Checking if Nexus is Ready..."
#   oc get pod -n ${GUID}-nexus|grep '\-2\-'|grep -v deploy|grep "1/1"
#   [[ "$?" == "1" ]] || break
#   echo "...no. Sleeping 10 seconds."
#   sleep 10
# done

# Ideally just calls a template
# oc new-app -f ../templates/nexus.yaml --param .....

# To be Implemented by Student


# oc project $NEXUS_PROJECT

# oc process -f ../templates/nexus-template.yml | oc create -f - -n $NEXUS_PROJECT 
# echo "Waiting for Nexus to deploy..."

# # sleep 60

while : ; do
  echo "Checking if Nexus is Ready..."
  http_code=$(curl -s -o /dev/null -w "%{http_code}" http://$(oc get route nexus3 --template='{{ .spec.host }}')/repository/maven-public/)
  echo "HTTP code returned is: " $http_code
  [[ "$http_code" != "200" ]] || break
  echo "...no. Sleeping 10 seconds."
  sleep 10
done


#configure nexus
echo "retrieving config via curl"
curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
chmod +x setup_nexus3.sh
./setup_nexus3.sh admin admin123 http://$(oc get route nexus3 --template='{{ .spec.host }}' -n $NEXUS_PROJECT)
rm setup_nexus3.sh

# TODO: this should be part of the template
oc annotate route nexus3 console.alpha.openshift.io/overview-app-route=true 
oc annotate route nexus-registry console.alpha.openshift.io/overview-app-route=false
