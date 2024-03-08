# IBM Security Verify SSO integration
This repo contains resources for integrating IBM Security Verify with JBoss or Wildfly using IBM Application Gateway as 
a web reverse proxy to manage authentication and authorization. Identity is supplied to the JBoss or Wildfly application 
server using a signed JWT.

Detailed documentation on this integration can be found at https://docs.verify.ibm.com/verify/docs/jboss

## Prerequisites
* Kubernetes
* Docker


## Domain name
The IBM Security Verify application must be configured with a redirect uri for the demo deployment. For this demo a [hosts 
file entry](https://en.wikipedia.org/wiki/Hosts_(file)) entry was used to set the Kubernetes cluster IPv4 address to route to
the `ibm.security.integration.demo` domain.


## Demo Web Application
This deployment relies on the JSP application built in [this](../demo_app) directory, a compiled application is available 
from the [releases](https://github.com/IBM-Security/ibm-security-integrations/releases) tab. The JBoss application should 
be copied to an archive called `JBOSS_SecTestWeb.war`.


## Environment variables
- `CLIENT_SECRET`: IBM Security Verify application client secret
- `CLIENT_ID`: IBM Security Verify application client id
- `DOCKER_SECRET`: docker.hub password to fetch IBM Application Gateway container
- `DOCKER_ID`: docker.hub username to fetch IBM Application Gateway container
- `VERIFY_TENANT`: domain name of IBM Security Verify tenant


## Deploying
The deployment of this demonstration is broken into three steps:
1. Generate or request the required PKI
For demonstration and testing, self signed certificates will suffice for securing connections between containers and IBM 
Security Verify.

```BASH
# IBM Application Gateway
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout iag.key -out iag.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo.iag.server"
openssl x509 -pubkey -noout -in iag.pem -out iag.pub
# Jboss/Wildlfy
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout wildfly.key -out wildfly.pem \
        -subj "$KID"
openssl pkcs12 -export -out application.keystore -inkey wildfly.key -in wildfly.pem -passout pass:demokeystore -name server
keytool -importcert -keystore application.keystore -file iag.pem -alias isvajwt -storepass demokeystore -noprompt
# IBM Security Verify tenant
echo -n | openssl s_client -connect $VERIFY_TENANT:443 | openssl x509 > verify_ca.pem
```


2. Configure the XML server configuration (standalone.xml)
The XML configuration file used by Wildfly or JBoss is subject to significant change between versions. Therefore this 
guide uses a `jboss_cli.sh` [batch script](elytron.cli) to add the required subsystem configuration to an existing file rather than 
check a configuration file into source.


The following commands are executed:
```
# Add a new token security realm to elytron for authentication using JWTs
/subsystem=elytron/token-realm=isva-jwt-realm:add(jwt={issuer=["www.ibm.com"],audience=["demo.integration.server"],key-map={"${KID}"="${PUBKEY}"}},principal-claim="sub")

# Add a new security domain, which uses the jwt security realm
/subsystem=elytron/security-domain=jwt-domain:add(realms=[{realm=isva-jwt-realm,role-decoder=groups-to-roles}],permission-mapper=default-permission-mapper,default-realm=isva-jwt-realm)

# Create http authentication factory that uses BEARER_TOKEN authentication
/subsystem=elytron/http-authentication-factory=jwt-http-authentication:add(security-domain=jwt-domain,http-server-mechanism-factory=global,mechanism-configurations=[{mechanism-name="BEARER_TOKEN",mechanism-realm-configurations=[{realm-name="isva-jwt-realm"}]}])

# Configure Undertow to use our http authentication factory for authentication
/subsystem=undertow/application-security-domain=ibm-verify-access-demo:add(http-authentication-factory=jwt-http-authentication,enable-jacc=true)

# Enable JACC, as this is how we get the principal name and groups in Java
/subsystem=elytron/policy=jacc:add(jacc-policy={})

```
> Note that `KID` and `PUBKEY` must either be replaced with actual values or environment variable substitution must be 
enabled when using the `jboss_cli.sh` tool. An example of this can be found in the `deploy_and_test.sh` [script](deploy_and_test.sh).


3. Deploy the Demo application with IBM Application Gateway
Once the PKI and server xml configuration is defined; the resulting files can be added to a Kubernetes ConfigMap and 
deployed. The template yaml files used for this use the `.tmpl` suffix; The `.macro_replace.sh` bash script is used to 
replace `%%MACRO%%` macros in the template files with the required configuration using Perl. There is a trick to this 
where the indentation when adding the values to the template files must match the expected yaml indentation.


4. Test out the integration\
To test out the integration open a new web browser and navigate to https://ibm.security.integration.demo:30443/wildflysso/SecTestWeb
