#!/bin/bash
# Copyright contributors to the IBM Security Integrations project

# Create certificates/keys
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout iag.key -out iag.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo.iag.server"
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout liberty.key -out liberty.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo.liberty.server"
openssl pkcs12 -export -out liberty.p12 -inkey liberty.key -in liberty.pem -passout pass:demokeystore
keytool -importcert -keystore liberty.p12 -file iag.pem -alias isvajwt -storepass demokeystore -noprompt
echo -n | openssl s_client -connect $VERIFY_TENANT:443 | openssl x509 > verify_ca.pem


# Deploy container to microk8s
./.macro_replace.sh server.xml LIBERTY_SecTestWeb.war verify_ca.pem liberty.pem iag.key iag.pem liberty.p12


# Test the deployment
./.validate.sh


# Clean up the artefacts
#./.clean.sh
