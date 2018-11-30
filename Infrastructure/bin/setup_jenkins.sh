#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
JENKINS_PROJECT=$GUID-jenkins
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"




# # Build a local docker image
# docker build . -t docker-registry-default.apps.testcoe3.appdevcoe.opentlc.com/briang-hw-jenkins/jenkins-slave-maven-appdev:v1

# # Login to the registry and then push your local image to remote
# docker login -u $(oc whoami) -p $(oc whoami -t) docker-registry-default.apps.testcoe3.appdevcoe.opentlc.com
# docker push docker-registry-default.apps.testcoe3.appdevcoe.opentlc.com/briang-hw-jenkins/jenkins-slave-maven-appdev:v1




# TODO:
# Create a project based on a template
# TODO: the template is referecing the briang hardcoded, should really be generic

oc project $JENKINS_PROJECT

echo "Creating jenkins"

oc process -f ../templates/jenkins-template.yml -p NAMESPACE=$JENKINS_PROJECT | oc create -f - -n $JENKINS_PROJECT

echo "Building the slave"

oc new-build --name=jenkins-slave-maven-appdev -D $'FROM docker.io/openshift/jenkins-slave-maven-centos7:v3.9\nUSER root\nRUN yum -y install skopeo\nUSER 1001' -n $JENKINS_PROJECT
sleep 120

echo "Configuring slave"
# configure kubernetes PodTemplate plugin.
oc new-app -f ../templates/jenkins-config.yml --param GUID=$GUID -n $JENKINS_PROJECT

echo "Slave configured"

oc process -f ../templates/build-config-pipeline-template.yml -p BUILD_NAME="nationalparks-pipeline" -p CONTEXT="./Nationalparks" -p GIT_URL=https://github.com/briangallagher/advdev_homework_template.git -p JENKINS_FILE_PATH="./Jenkinsfile" | oc create -f - 
oc process -f ../templates/build-config-pipeline-template.yml -p BUILD_NAME="mlbparks-pipeline" -p CONTEXT="./MLBParks" -p GIT_URL=https://github.com/briangallagher/advdev_homework_template.git -p JENKINS_FILE_PATH="./Jenkinsfile" | oc create -f - 
oc process -f ../templates/build-config-pipeline-template.yml -p BUILD_NAME="parksmap-pipeline" -p CONTEXT="./ParksMap" -p GIT_URL=https://github.com/briangallagher/advdev_homework_template.git -p JENKINS_FILE_PATH="./Jenkinsfile" | oc create -f - 

sleep 60

echo "setting required envars for the build configs.."
oc set env bc/mlbparks-pipeline GUID=$GUID CLUSTER=$CLUSTER -n $JENKINS_PROJECT
oc set env bc/nationalparks-pipeline GUID=$GUID CLUSTER=$CLUSTER -n $JENKINS_PROJECT
oc set env bc/parksmap-pipeline GUID=$GUID CLUSTER=$CLUSTER -n $JENKINS_PROJECT


# Code to set up the Jenkins project to execute the
# three pipelines.
# This will need to also build the custom Maven Slave Pod
# Image to be used in the pipelines.
# Finally the script needs to create three OpenShift Build
# Configurations in the Jenkins Project to build the
# three micro services. Expected name of the build configs:
# * mlbparks-pipeline
# * nationalparks-pipeline
# * parksmap-pipeline
# The build configurations need to have two environment variables to be passed to the Pipeline:
# * GUID: the GUID used in all the projects
# * CLUSTER: the base url of the cluster used (e.g. na39.openshift.opentlc.com)

# To be Implemented by Student



