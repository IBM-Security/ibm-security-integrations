#!/bin/bash
# Copyright contributors to the IBM Security Integrations project

if [ "$#" -ne "8" ]; then
    echo "Usage: ./$0 <sever.xml> <logging.properties> <demo.application.war> <verify_ca.pem> <integration_target.pem> <iag.key> <iag.pem> <integration_target.p12>"
    exit 1
fi

echo "Deploying Tomcat. . ."

# $1 == server.xml
# $3 == demoapp.war
# $2 == logging.properties
# $7 == iag.pem
# $8 == tomcat.p12
python - "$1" "$3" "$2" "$7" "$8" <<EOF | kubectl create -f -
import base64
import glob
import sys
f = open('tomcat-integration.tmpl', 'rb')
tomcat = f.read()
f.close()
macros = {
    b'%%JAKARTA_SERLVET_API_JAR%%': base64.b64encode(open(glob.glob('lib/jakarta.servlet-api*.jar')[0], 'rb').read()),
    b'%%JAKARTA_JACC_JAR%%': base64.b64encode(open(glob.glob('lib/jboss-jacc-api*.jar')[0], 'rb').read()),
    b'%%JOSE4J_JAR%%': base64.b64encode(open(glob.glob('lib/jose4j*.jar')[0], 'rb').read()),
    b'%%SLF4J_JAR%%': base64.b64encode(open(glob.glob('lib/slf4j-api*.jar')[0], 'rb').read()),
    b'%%IBM_SECURITY_JWT_VALVE_JAR%%': base64.b64encode(open(glob.glob('build/jar/*.jar')[0], 'rb').read()),
    b'%%SERVER_XML%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[1], 'rb').readlines()]),
    b'%%LOGGING_PROPERTIES%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[3], 'rb').readlines()]),
    b'%%DEMO_APPLICATION%%': base64.b64encode(open(sys.argv[2], 'rb').read()),
    b'%%DEMO_KEYSTORE%%': base64.b64encode(open(sys.argv[5], 'rb').read()),
    b'%%IAG_CERTIFICATE%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[4], 'rb').readlines()]),
}
for k, v in macros.items():
    tomcat = tomcat.replace(k, v)
print(tomcat.decode())
EOF

echo "Deploying IAG. . ."

# $4 = verify.tenant.pem
# $5 = integration.target.pem
# $6 = iag.key
# $7 = iag.pem
python - "$4" "$5" "$6" "$7" <<EOF | kubectl create -f -
import base64, sys, os, json
f = open('iag-integration.tmpl', 'rb')
tomcat = f.read()
f.close()
macros = {
    b'%%VERIFY_TENANT_CERT%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[1], 'rb').readlines()]),
    b'%%INTEGRATION_SERVER_CERTIFICATE%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[2], 'rb').readlines()]),
    b'%%IAG_KEY%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[3], 'rb').readlines()]),
    b'%%IAG_CERTIFICATE%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[4], 'rb').readlines()]),
    b'%%CLIENT_ID%%': base64.b64encode(os.environ.get('CLIENT_ID').encode()),
    b'%%CLIENT_SECRET%%': base64.b64encode(os.environ.get('CLIENT_SECRET').encode()),
    b'%%VERIFY_TENANT%%': os.environ.get('VERIFY_TENANT').encode(),
    b'%%DOCKER_LOGIN%%': base64.b64encode( json.dumps({ 
        "auths": { "https://registry-1.docker.io/v2/":
                        { "username" : os.environ.get('DOCKER_ID'),
                          "password" : os.environ.get('DOCKER_SECRET'),
                          "auth": base64.b64encode( os.environ.get('DOCKER_ID').encode() + b":" + \
                                     os.environ.get('DOCKER_SECRET').encode() ).decode('utf-8')}}}).encode())
}
for k, v in macros.items():
    tomcat = tomcat.replace(k, v)
print(tomcat.decode())
EOF
#cat iag-integration.tmpl |
#    perl -p -e "s|%%VERIFY_TENANT_CERT%%|${VERIFY_TENANT_PEM}|g; 
#                s|%%INTEGRATION_SERVER_CERTIFICATE%%|${INTEGRATION_TARGET_PEM}|g; 
#                s|%%IAG_KEY%%|${IAG_KEY}|g; 
#                s|%%IAG_CERTIFICATE%%|${IAG_PEM}|g; 
#                s|%%CLIENT_ID%%|$CLIENT_ID|g; 
#                s|%%CLIENT_SECRET%%|$CLIENT_SECRET|g;
#                s|%%VERIFY_TENANT%%|$VERIFY_TENANT|g;
#                s|%%DOCKER_LOGIN%%|$DOCKER_LOGIN|g;" \
#    | kubectl create -f -
##--dry-run=client --output yaml 
##SERVER_XML="$( sed -e 's/\(^.*\)/    \1/g' $1 )"
##DEMO_APPLICATION="$( cat $2 | base64 -w0 )"
#VERIFY_TENANT_PEM="$( cat $4 | sed -e 's/\(^.*\)/    \1/g' )"
#INTEGRATION_TARGET_PEM="$( cat $5 | sed -e 's/\(^.*\)/    \1/g' )"
#IAG_KEY="$( cat $6 | sed -e 's/\(^.*\)/    \1/g' )"
#IAG_PEM="$( cat $7 | sed -e 's/\(^.*\)/    \1/g' )"
##INTEGRATION_TARGET_ENCODED="$( cat $8 | base64 -w0 )"
#CLIENT_ID="$( echo "${CLIENT_ID:-abcd1234}" | base64 -w0 )"
#CLIENT_SECRET="$( echo "${CLIENT_SECRET:-abcd1234}" | base64 -w0 )"
#VERIFY_TENANT="${VERIFY_TENANT:-my.verify.tenant}"
#DOCKER_ID="${DOCKER_ID:-username}"
#DOCKER_SECRET="${DOCKER_SECRET:-password}"
#DOCKER_LOGIN="$(echo "{\"auths\": {\"https://registry-1.docker.io/v2/\": {\"username\": \"$DOCKER_ID\", 
#        \"password\": \"$DOCKER_SECRET\", \"auth\": \"$(echo "$DOCKER_ID:$DOCKER_SECRET" | base64 -w0 )\"}}}" \
#        | jq -c . | base64 -w0)"
#DOCKER_LOGIN="$(echo "{\"auths\": {\"https://index.docker.io/v1/\": {\"username\": \"$DOCKER_ID\", 
#        \"password\": \"$DOCKER_SECRET\", \"auth\": \"$(echo "$DOCKER_ID:$DOCKER_SECRET" | base64 -w0 )\"}}}" \
#        | jq -c . | base64 -w0)"
