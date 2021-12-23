#!/bin/bash
# Copyright contributors to the IBM Security Integrations project

# IAG key X500 distinguished name
KID="/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo-iag-server"

# Create certificates/keys
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout iag.key -out iag.pem \
        -subj "$KID"
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout tomcat.key -out tomcat.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo-tomcat-server"
openssl pkcs12 -export -out tomcat.p12 -inkey tomcat.key -in tomcat.pem -passout pass:demokeystore
keytool -importcert -keystore tomcat.p12 -file iag.pem -alias "$KID" -storepass demokeystore -noprompt
echo -n | openssl s_client -connect $VERIFY_TENANT:443 | openssl x509 > verify_ca.pem


# Fetch dependencies from Maven
mvn dependency:copy-dependencies
# Build valve
ant


# Deploy container to microk8s
./.macro_replace.sh server.xml logging.properties TOMCAT_SecTestWeb.war verify_ca.pem tomcat.pem iag.key iag.pem tomcat.p12
