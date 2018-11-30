#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
SONAR_PROJECT=$GUID-sonarqube
echo "Setting up Sonarqube in project $SONAR_PROJECT"

# Code to set up the SonarQube project.
# Ideally just calls a template
# oc new-app -f ../templates/sonarqube.yaml --param .....

# To be Implemented by Student
oc project $SONAR_PROJECT

echo "Deploying Postgres..."
oc process -f ../templates/postgres-template.yml | oc create -f - -n $SONAR_PROJECT

while : ; do
  echo "Checking if Postgres is Ready..."
  output=$(oc get pods --field-selector=status.phase='Running' -n $SONAR_PROJECT| grep 'postgresql' | grep -v 'deploy' | grep '1/1' | awk '{print $2}')
  [[ "${output}" != "1/1" ]] || break #testing here
  echo "...no Sleeping 20 seconds."
  sleep 20
done
echo "Postgresql Deployment complete"

echo "Deploying Sonarqube..."
oc process -f ../templates/sonar-template.yml | oc create -f - -n $SONAR_PROJECT

while : ; do
  echo "Checking if Sonarqube is Ready..."
  output=$(oc get pods --field-selector=status.phase='Running' -n $SONAR_PROJECT| grep 'sonarqube' | grep -v 'deploy' | grep '1/1' | awk '{print $2}')
  [[ "${output}" != "1/1" ]] || break #testing here
  echo "...no Sleeping 20 seconds."
  sleep 20
done

echo "Sonarqube Deployment complete"

