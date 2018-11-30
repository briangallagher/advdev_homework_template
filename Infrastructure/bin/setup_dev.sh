#!/bin/bash
# Setup Development Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
DEV_PROJECT=$GUID-parks-dev
PROD_PROJECT=$GUID-parks-prod

echo "Setting up Parks Development Environment in project ${GUID}-parks-dev"

# Code to set up the parks development project.

# To be Implemented by Student
# Grant the correct permissions to the Jenkins service account
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n ${DEV_PROJECT}
oc policy add-role-to-user admin system:serviceaccount:$GUID-jenkins:jenkins -n ${DEV_PROJECT}
oc policy add-role-to-user view system:serviceaccount:default -n ${DEV_PROJECT}

# This is not needed yet.
#oc policy add-role-to-group system:image-puller system:serviceaccounts:${PROD_PROJECT} -n ${DEV_PROJECT}

oc project $DEV_PROJECT

# ------------------------------------------------------------------------------------------------------


# Create a MongoDB database

oc process -f ../templates/mongodb-single-template.yml | oc create -f - -n ${DEV_PROJECT}

# Pause here until confirmation that Mongo is running
while : ; do
  echo "Checking if Mongodb is Ready..."
  output=$(oc get pods --field-selector=status.phase='Running' | grep 'mongodb' | grep -v 'deploy' | grep '1/1' | awk '{print $2}')
  [[ "${output}" != "1/1" ]] || break #testing here
  echo "...no Sleeping 10 seconds."
  sleep 10
done
echo "Mongodb Deployment complete"

# Create binary build config here to be used in the Jenkins pipeline. 
# The pipeline will inject the binary and then start a build below
# for example: oc start-build parksmap --follow --from-file=./target/parksmap.jar -n $GUID-parks-dev
echo "Creating binary build configs.."
oc new-build --binary=true --name="mlbparks" -i=jboss-eap70-openshift:1.7 -n $DEV_PROJECT
oc new-build --binary=true --name="nationalparks" -i=redhat-openjdk18-openshift:1.2 -n $DEV_PROJECT
oc new-build --binary=true --name="parksmap" -i=redhat-openjdk18-openshift:1.2 -n $DEV_PROJECT


# Set up placeholder deployment configs that will be updated in time
echo "Creating Deployment Configs.."
oc new-app $DEV_PROJECT/mlbparks --name=mlbparks -n $DEV_PROJECT
oc new-app $DEV_PROJECT/nationalparks --name=nationalparks -n $DEV_PROJECT
oc new-app $DEV_PROJECT/parksmap --name=parksmap -n $DEV_PROJECT

# Turn off triggers
echo "Turning off all depoyment triggers as deployments will be controlled by the pipeline"
oc set triggers dc/mlbparks --remove-all -n $DEV_PROJECT
oc set triggers dc/nationalparks --remove-all -n $DEV_PROJECT
oc set triggers dc/parksmap --remove-all -n $DEV_PROJECT

# The following environment variables are defined in the READMEs for all 3 apps
echo "Create Configmaps.."
oc create configmap mlbparks-config --from-literal="DB_HOST=mongodb " --from-literal="DB_PORT=27017" \
 --from-literal="DB_USERNAME=mongodb" --from-literal="DB_PASSWORD=mongodb" \
 --from-literal="DB_NAME=parks" --from-literal="DB_REPLICASET=rs0" \
 --from-literal="APPNAME=MLB Parks (Green)" -n $DEV_PROJECT

oc create configmap nationalparks-config --from-literal="DB_HOST=mongodb " --from-literal="DB_PORT=27017" \
 --from-literal="DB_USERNAME=mongodb" --from-literal="DB_PASSWORD=mongodb" \
 --from-literal="DB_NAME=parks" --from-literal="DB_REPLICASET=rs0" \
 --from-literal="APPNAME=National Parks (Green)" -n $DEV_PROJECT

# No mongo stuff required here TODO: confirm env vars are not required
oc create configmap parksmap-config --from-literal="APPNAME=ParksMap (Green)" -n $DEV_PROJECT

echo "Update the DeploymentConfig to use the configmaps.. "
oc set env dc/mlbparks --from=configmap/mlbparks-config
oc set env dc/nationalparks --from=configmap/nationalparks-config
oc set env dc/parksmap --from=configmap/parksmap-config

echo "Creating services.."
oc expose dc/mlbparks --port 8080 -n $DEV_PROJECT
oc expose dc/nationalparks --port 8080 -n $DEV_PROJECT
oc expose dc/parksmap --port 8080 -n $DEV_PROJECT

# The service to the application needs a label `type=parksmap-backend` for the frontend to dynamically discover the service.
echo "Creating labels for backend"
oc label svc/mlbparks type=parksmap-backend -n $DEV_PROJECT
oc label svc/nationalparks type=parksmap-backend -n $DEV_PROJECT

# TODO: Not doing either of below yet.
# Set deployment hooks to populate the database for the back end services
# Set up liveness and readiness probes









