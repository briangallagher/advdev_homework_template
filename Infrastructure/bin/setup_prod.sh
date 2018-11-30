#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
PROD_PROJECT=$GUID-parks-prod
DEV_PROJECT=$GUID-parks-dev
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.


# ------------------------------------------------------------------------------------------
# --------------------- Permissions ---------------------
# ------------------------------------------------------------------------------------------

# Grant the correct permissions to the Jenkins service account
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n ${PROD_PROJECT}
oc policy add-role-to-user admin system:serviceaccount:$GUID-jenkins:jenkins -n ${PROD_PROJECT}
# Grant the correct permissions to pull images from the development project
oc policy add-role-to-group system:image-puller system:serviceaccounts:${PROD_PROJECT} -n ${DEV_PROJECT}

# Grant the correct permissions for the ParksMap application to read back-end services (see the associated README file)
# Not sure if below covers this ???? TODO:
oc policy add-role-to-user view system:serviceaccount:default -n ${PROD_PROJECT}

# Switch to prod project
oc project $PROD_PROJECT


# ------------------------------------------------------------------------------------------
# --------------------- Mongo ---------------------
# ------------------------------------------------------------------------------------------

# Set up a replicated MongoDB database via StatefulSet with at least three replicas 


echo "Creating internal mongo service.."
oc create -f ../templates/mongodb-service-internal-template.yml -n ${PROD_PROJECT}

echo "Creating mongo service.."
oc create -f ../templates/mongodb-service-template.yml -n ${PROD_PROJECT}

# TODO: Readiness probe is commented out
echo "Creating mongo StatefulSet.."
oc create -f ../templates/mongodb-statefulset-template.yml -n ${PROD_PROJECT}

echo "Checking if Mongodb Stateful set is Ready..."
check_if_ready () {
   while : ; do
     echo "Checking mongodb-$1 pod.."
     output=$(oc get pods --field-selector=status.phase='Running'| grep 'mongodb-'$1 | grep '1/1' | awk '{print $2}')
     echo $output
   [[ "${output}" != "1/1" ]] || break #testing here
   echo "...no Sleeping 10 seconds."
   sleep 10
   done  
} 

check_if_ready "0"
check_if_ready "1"
check_if_ready "2"

echo "Mongodb Deployment complete"

# ------------------------------------------------------------------------------------------
# --------------------- ??????? ---------------------
# ------------------------------------------------------------------------------------------

echo "Creating Blue Deployment Configs.."
oc new-app $DEV_PROJECT/mlbparks --name=mlbparks-blue -n $PROD_PROJECT
oc new-app $DEV_PROJECT/nationalparks --name=nationalparks-blue -n $PROD_PROJECT
oc new-app $DEV_PROJECT/parksmap --name=parksmap-blue -n $PROD_PROJECT

# TODO: Investigate why :0.0 and --allow-missing-imagestream-tags=true are required.
# oc new-app $DEV_PROJECT/parksmap:0.0 --name=parksmap-blue --allow-missing-imagestream-tags=true -n $PROD_PROJECT

echo "Setting Blue triggers.."
oc set triggers dc/mlbparks-blue --remove-all -n $PROD_PROJECT
oc set triggers dc/nationalparks-blue --remove-all -n $PROD_PROJECT
oc set triggers dc/parksmap-blue --remove-all -n $PROD_PROJECT

echo "Creating Green Deployment Configs.."
oc new-app $DEV_PROJECT/mlbparks --name=mlbparks-green -n $PROD_PROJECT
oc new-app $DEV_PROJECT/nationalparks --name=nationalparks-green -n $PROD_PROJECT
oc new-app $DEV_PROJECT/parksmap --name=parksmap-green -n $PROD_PROJECT

echo "Setting Green triggers.."
oc set triggers dc/mlbparks-green --remove-all -n $PROD_PROJECT
oc set triggers dc/nationalparks-green --remove-all -n $PROD_PROJECT
oc set triggers dc/parksmap-green --remove-all -n $PROD_PROJECT

echo "Create Configmaps (Blue).."
oc create configmap mlbparks-config-blue --from-literal="DB_HOST=mongodb " --from-literal="DB_PORT=27017" \
 --from-literal="DB_USERNAME=mongodb" --from-literal="DB_PASSWORD=mongodb" \
 --from-literal="DB_NAME=parks" --from-literal="DB_REPLICASET=rs0" \
 --from-literal="APPNAME=MLB Parks (Blue)" -n $PROD_PROJECT

oc create configmap nationalparks-config-blue --from-literal="DB_HOST=mongodb " --from-literal="DB_PORT=27017" \
 --from-literal="DB_USERNAME=mongodb" --from-literal="DB_PASSWORD=mongodb" \
 --from-literal="DB_NAME=parks" --from-literal="DB_REPLICASET=rs0" \
 --from-literal="APPNAME=National Parks (Blue)" -n $PROD_PROJECT

oc create configmap parksmap-config-blue --from-literal="APPNAME=ParksMap (Blue)" -n $PROD_PROJECT

echo "Create Configmaps (Green).."
oc create configmap mlbparks-config-green --from-literal="DB_HOST=mongodb " --from-literal="DB_PORT=27017" \
 --from-literal="DB_USERNAME=mongodb" --from-literal="DB_PASSWORD=mongodb" \
 --from-literal="DB_NAME=parks" --from-literal="DB_REPLICASET=rs0" \
 --from-literal="APPNAME=MLB Parks (Green)" -n $PROD_PROJECT

oc create configmap nationalparks-config-green --from-literal="DB_HOST=mongodb " --from-literal="DB_PORT=27017" \
 --from-literal="DB_USERNAME=mongodb" --from-literal="DB_PASSWORD=mongodb" \
 --from-literal="DB_NAME=parks" --from-literal="DB_REPLICASET=rs0" \
 --from-literal="APPNAME=National Parks (Green)" -n $PROD_PROJECT

oc create configmap parksmap-config-green --from-literal="APPNAME=ParksMap (Green)" -n $PROD_PROJECT

echo "Update the DeploymentConfig to use the configmaps.. "
oc set env dc/mlbparks-blue --from=configmap/mlbparks-config-blue -n ${PROD_PROJECT}
oc set env dc/nationalparks-blue --from=configmap/nationalparks-config-blue -n ${PROD_PROJECT}
oc set env dc/parksmap-blue --from=configmap/parksmap-config-blue -n ${PROD_PROJECT}

echo "Update the DeploymentConfig to use the configmaps.. "
oc set env dc/mlbparks-green --from=configmap/mlbparks-config-green -n $PROD_PROJECT
oc set env dc/nationalparks-green --from=configmap/nationalparks-config-green -n $PROD_PROJECT
oc set env dc/parksmap-green --from=configmap/parksmap-config-green -n $PROD_PROJECT

echo "Creating services for green.."
oc expose dc/mlbparks-green  --port 8080 -n $PROD_PROJECT
oc expose dc/nationalparks-green  --port 8080 -n $PROD_PROJECT
oc expose dc/parksmap-green  --port 8080 -n $PROD_PROJECT

echo "Creating services for blue.."
oc expose dc/mlbparks-blue --port 8080 -n $PROD_PROJECT
oc expose dc/nationalparks-blue --port 8080 -n $PROD_PROJECT
oc expose dc/parksmap-blue --port 8080 -n $PROD_PROJECT

echo "label the backend services"
oc label svc/mlbparks-green type=parksmap-backend -n $PROD_PROJECT
oc label svc/nationalparks-green type=parksmap-backend -n $PROD_PROJECT

echo "label the backend services"
oc label svc/mlbparks-blue type=parksmap-backend -n $PROD_PROJECT
oc label svc/nationalparks-blue type=parksmap-backend -n $PROD_PROJECT

echo "create routes for blue service"
oc expose svc/mlbparks-blue --name mlbparks -n $PROD_PROJECT
oc expose svc/nationalparks-blue --name nationalparks -n $PROD_PROJECT  
oc expose svc/parksmap-blue --name parksmap -n $PROD_PROJECT 

echo "Finished Setting up Production Apps!"


















