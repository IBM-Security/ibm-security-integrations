#!/bin/bash

# KID is used to identify the key in wildlfly/jboss
KID="/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo.integration.server"

# Create certificates/keys
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout iag.key -out iag.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo.iag.server"
openssl x509 -pubkey -noout -in iag.pem -out iag.pub
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout wildfly.key -out wildfly.pem \
        -subj "$KID"
openssl pkcs12 -export -out application.keystore -inkey wildfly.key -in wildfly.pem -passout pass:demokeystore -name server
keytool -importcert -keystore application.keystore -file iag.pem -alias isvajwt -storepass demokeystore -noprompt
echo -n | openssl s_client -connect $VERIFY_TENANT:443 | openssl x509 > verify_ca.pem


# Fetch and modify the latest standalone.xml config file.
TEMP_CONTAINER="integration_builder"
docker run -i --name $TEMP_CONTAINER -v iag.pub:/opt/jboss/iag.pub jboss/wildfly bash -s <<EOF
/opt/jboss/wildfly/bin/standalone.sh &
# Wait for server to start
sleep 30
sed -i -e 's/resolve-parameter-values>false/resolve-parameter-values>true/g' \$JBOSS_HOME/bin/jboss-cli.xml

PUBKEY="$( cat iag.pub )"

/opt/jboss/wildfly/bin/jboss-cli.sh --connect <<JBOSS
batch

# Add a new token security realm to elytron for authentication using JWTs
/subsystem=elytron/token-realm=isva-jwt-realm:add(jwt={issuer=["www.ibm.com"],audience=["demo.integration.server"],key-map={"${KID}"="\${PUBKEY}"}},principal-claim="sub")

# Add a new security domain, which uses the jwt security realm
/subsystem=elytron/security-domain=jwt-domain:add(realms=[{realm=isva-jwt-realm,role-decoder=groups-to-roles}],permission-mapper=default-permission-mapper,default-realm=isva-jwt-realm)

# Create http authentication factory that uses BEARER_TOKEN authentication
/subsystem=elytron/http-authentication-factory=jwt-http-authentication:add(security-domain=jwt-domain,http-server-mechanism-factory=global,mechanism-configurations=[{mechanism-name="BEARER_TOKEN",mechanism-realm-configurations=[{realm-name="isva-jwt-realm"}]}])

# Configure Undertow to use our http authentication factory for authentication
/subsystem=undertow/application-security-domain=ibm-verify-access-demo:add(http-authentication-factory=jwt-http-authentication)

run-batch
reload
exit
JBOSS

#Finally need to replace the default keystore config with the pcks12 created above
sed -i -e 's/clear-text="password"/clear-text="demokeystore"/g' -e 's/JKS/PKCS12/g' \$JBOSS_HOME/standalone/configuration/standalone.xml
EOF

docker cp $( docker ps -a -q --filter="NAME=$TEMP_CONTAINER" ):/opt/jboss/wildfly/standalone/configuration/standalone.xml .
docker rm $( docker ps -a -q --filter="NAME=$TEMP_CONTAINER" )

# Deploy container to microk8s
./.macro_replace.sh stanalone.xml DemoApplication.war verify_ca.pem wildfly.pem iag.key iag.pem application.keystore
