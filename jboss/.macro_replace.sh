#!/bin/bash

if [ "$#" -ne "7" ]; then
    echo "Usage: ./$0 <standalone.xml> <demo.application.war> <verify_ca.pem> <integration_target.pem> <iag.key> <iag.pem> <integration_target.p12>"
    exit 1
fi

STANDALONE_XML="$( cat $1 | sed -e 's/\(^.*\)/    \1/g' )"
DEMO_APPLICATION="$( cat $2 | base64 -w0 )"
VERIFY_TENANT_PEM="$( cat $3 | sed -e 's/\(^.*\)/    \1/g' )"
INTEGRATION_TARGET_PEM="$( cat $4 | sed -e 's/\(^.*\)/    \1/g' )"
IAG_KEY="$( cat $5 | sed -e 's/\(^.*\)/    \1/g' )"
IAG_PEM="$( cat $6 | sed -e 's/\(^.*\)/    \1/g' )"
INTEGRATION_TARGET_ENCODED="$( cat $7 | base64 -w0 )"
CLIENT_ID="$( echo "${CLIENT_ID:-abcd1234}" | base64 -w0 )"
CLIENT_SECRET="$( echo "${CLIENT_SECRET:-abcd1234}" | base64 -w0 )"
DOCKER_ID="${DOCKER_ID:-username}"
DOCKER_SECRET="${DOCKER_SECRET:-password}"
DOCKER_LOGIN="$(echo "{\"auths\": {\"https://index.docker.io/v1/\": {\"username\": \"$DOCKER_ID\", 
        \"password\": \"$DOCKER_SECRET\", \"auth\": \"$(echo "$DOCKER_ID:$DOCKER_SECRET" | base64 -w0 )\"}}}" \
        | jq -c . | base64 -w0)"

echo "Deploying Liberty:"

cat wildfly-integration.tmpl |
    perl -p -e "s|%%WILDFLY_KEYSTORE%%|${INTEGRATION_TARGET_ENCODED}|g;
                s|%%DEMO_APPLICATION%%|${DEMO_APPLICATION}|g;
                s|%%STANDALONE_XML%%|${STANDALONE_XML}|g;" \
    | kubectl create -f -

echo "Deploying IAG: "

cat iag-integration.tmpl |
    perl -p -e "s|%%VERIFY_TENANT_CERT%%|${VERIFY_TENANT_PEM}|g; 
                s|%%INTEGRATION_SERVER_CERTIFICATE%%|${INTEGRATION_TARGET_PEM}|g; 
                s|%%IAG_KEY%%|${IAG_KEY}|g; 
                s|%%IAG_CERTIFICATE%%|${IAG_PEM}|g; 
                s|%%CLIENT_ID%%|$CLIENT_ID|g; 
                s|%%CLIENT_SECRET%%|$CLIENT_SECRET|g;
                s|%%DOCKER_LOGIN%%|$DOCKER_LOGIN|g;" \
    | kubectl create -f -
#--dry-run=client --output yaml 
