#!/bin/bash

if [ "$#" -ne "7" ]; then
    echo "Usage: ./$0 <sever.xml> <demo.application.war> <verify_ca.pem> <integration_target.pem> <iag.key> <iag.pem> <integration_target.p12>"
    exit 1
fi

echo "Deploying Liberty:"

# $1 == server.xml
# $2 == DemoApp.war
# $7 == liberty.p12
python - "$1" "$2" "$7" <<EOF | kubectl create -f -
import base64, sys
f = open('liberty-integration.tmpl', 'rb')
tomcat = f.read()
f.close()
macros = {
    b'%%LIBERTY_KEYSTORE%%': base64.b64encode(open(sys.argv[3], 'rb').read()),
    b'%%DEMO_APPLICATION%%': base64.b64encode(open(sys.argv[2], 'rb').read()),
    b'%%SERVER_XML%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[1], 'rb').readlines()]),
}
for k, v in macros.items():
    tomcat = tomcat.replace(k, v)
print(tomcat.decode())
EOF



echo "Deploying IAG: "

# $3 == verify.tenant.pem
# $4 == liberty.pem
# $5 == iag.key
# $6 == iag.pem
python - "$3" "$4" "$5" "$6" <<EOF | kubectl create -f -
import base64, sys, os, json
f = open('iag-integration.tmpl', 'rb')
tomcat = f.read()
f.close()
macros = {
    b'%%VERIFY_TENANT_CERT%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[1], 'rb').readlines()]),
    b'%%INTEGRATION_SERVER_CERTIFICATE%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[2], 'rb').readlines()]),
    b'%%IAG_KEY%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[3], 'rb').readlines()]),
    b'%%IAG_CERTIFICATE%%': b''.join([b''.join([b'    ', s]) for s in open(sys.argv[4], 'rb').readlines()]),
    b'%%VERIFY_TENANT%%': os.environ.get('VERIFY_TENANT').encode(),
    b'%%CLIENT_ID%%': base64.b64encode(os.environ.get('CLIENT_ID').encode()),
    b'%%CLIENT_SECRET%%': base64.b64encode(os.environ.get('CLIENT_SECRET').encode()),
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
