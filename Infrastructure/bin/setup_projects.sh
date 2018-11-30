#!/bin/bash
# Create all Homework Projects
if [ "$#" -ne 2 ]; then
    echo "Usage:"
    echo "  $0 GUID USER"
    exit 1
fi

GUID=$1
USER=$2
echo "Creating all Homework Projects for GUID=${GUID} and USER=${USER}"
oc new-project ${GUID}-nexus3     --display-name="${GUID} AdvDev Homework Nexus 3"
oc new-project ${GUID}-sonarqube  --display-name="${GUID} AdvDev Homework Sonarqube"
oc new-project ${GUID}-jenkins    --display-name="${GUID} AdvDev Homework Jenkins"
oc new-project ${GUID}-parks-dev  --display-name="${GUID} AdvDev Homework Parks Development"
oc new-project ${GUID}-parks-prod --display-name="${GUID} AdvDev Homework Parks Production"

oc policy add-role-to-user admin ${USER} -n ${GUID}-nexus3
oc policy add-role-to-user admin ${USER} -n ${GUID}-sonarqube
oc policy add-role-to-user admin ${USER} -n ${GUID}-jenkins
oc policy add-role-to-user admin ${USER} -n ${GUID}-parks-dev
oc policy add-role-to-user admin ${USER} -n ${GUID}-parks-prod


# Below gives the following errors:::
# Error from server (Forbidden): namespaces "83ae-jenkins" is forbidden: User "bgallagh-redhat.com" cannot patch namespaces in the namespace "83ae-jenkins": User "bgallagh-redhat.com" cannot "patch" "namespaces" with name "83ae-jenkins" in project "83ae-jenkins"

# oc annotate namespace ${GUID}-nexus3     openshift.io/requester=${USER} --overwrite
# oc annotate namespace ${GUID}-sonarqube  openshift.io/requester=${USER} --overwrite
# oc annotate namespace ${GUID}-jenkins    openshift.io/requester=${USER} --overwrite
# oc annotate namespace ${GUID}-parks-dev  openshift.io/requester=${USER} --overwrite
# oc annotate namespace ${GUID}-parks-prod openshift.io/requester=${USER} --overwrite
# 