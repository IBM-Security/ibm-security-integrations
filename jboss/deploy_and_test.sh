#!/bin/bash
# Copyright contributors to the IBM Security Integrations project

# KID is used to identify the key in wildlfly/jboss

# Create certificates/keys
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout iag.key -out iag.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo.iag.server"
#KID used to identify key in JWT header so this must match config in Wildfly/JBoss
KID="CN=demo.iag.server,O=IBM,L=Gold Coast,ST=QLD,C=AU"
openssl x509 -pubkey -noout -in iag.pem -out iag.pub
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout wildfly.key -out wildfly.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=wildfly-integration"
openssl pkcs12 -export -out application.keystore -inkey wildfly.key -in wildfly.pem -passout pass:demokeystore -name server
keytool -importcert -keystore application.keystore -file iag.pem -alias "$KID" -storepass demokeystore -noprompt
echo -n | openssl s_client -connect $VERIFY_TENANT:443 | openssl x509 > verify_ca.pem


# Fetch and modify the latest standalone.xml config file.
TEMP_CONTAINER="integration_builder"
docker run -i --name $TEMP_CONTAINER -v iag.pub:/opt/jboss/iag.pub jboss/wildfly bash -s <<EOF
/opt/jboss/wildfly/bin/standalone.sh &
# Wait for server to start
sleep 10
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

 /subsystem=elytron/policy=jacc:add(jacc-policy={})
reload

# Configure Undertow to use our http authentication factory for authentication
/subsystem=undertow/application-security-domain=ibm-verify-access-demo:add(http-authentication-factory=jwt-http-authentication,enable-jacc=true)

# Add some logging for demonstration purposes
/subsystem=logging/logger=org.wildfly:add
/subsystem=logging/logger=org.wildfly:write-attribute(name="level", value="ALL")
/subsystem=logging/logger=io.undetow:add
/subsystem=logging/logger=io.undetow:write-attribute(name="level", value="ALL")
/subsystem=logging/logger=org.jboss.security:add
/subsystem=logging/logger=org.jboss.security:write-attribute(name="level", value="ALL")

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
./.macro_replace.sh standalone.xml JBOSS_SecTestWeb.war verify_ca.pem wildfly.pem iag.key iag.pem application.keystore
