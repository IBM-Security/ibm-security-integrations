# Tomcat JWT Authentication
This repo contains resources for integrating IBM Security Verify with Apache Tomcat using IBM Application Gateway as a 
web reverse proxy to manage authentication and authorization. Identity is supplied to the Apache Tomcat application server
via a signed JWT.


## Prerequisites
- Apace Ant\*
- Maven\*
- Kubernetes
> only required if building from source code


# Demo Web Application\
This deployment relies on the JSP application built in [this](../demo_app) directory, a compiled application is available 
from the [releases](https://github.com/IBM-Security/ibm-security-integrations/releases) tab. The Tomcat application 
should be copied to an archive called `TOMCAT_SecTestWeb.war` to be compatible with the provided shell scripts.


## Building Valve
1. Fetch dependencies from Maven\
Maven is used here because it allows us to fetch jars into a directory we define very easily. This is important not only 
for compiling the Valve in the next step but also for eventually adding the dependencies to Tomcat container we will 
test the Valve with.

`mvn clean dependency:copy-dependencies`


2. Build the JWT SSO Valve\
Use Apache Ant to build the Java code into a thin jar.

`ant jar`


## Environment variables
- `CLIENT_SECRET`: IBM Security Verify application client secret
- `CLIENT_ID`: IBM Security Verify application client id
- `DOCKER_SECRET`: docker.hub password to fetch IBM Application Gateway container
- `DOCKER_ID`: docker.hub username to fetch IBM Application Gateway container
- `VERIFY_TENANT`: domain name of IBM Security Verify tenant


## Deploying
The deployment of this demonstration is broken into three steps:\
1. Get the JWT SSO Valve.\
This can be built from source code or use the latest compiled [jar](https://github.com/IBM-Security/ibm-security-integrations/releases/latest). 
If you are using the latest jar you will also need to fetch a copy of the dependency jars.

2. Generate or request the required PKI\
For demonstration and testing, self signed certificates will suffice for securing connections between containers and IBM 
Security Verify.

```BASH
# IBM Application Gateway
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout iag.key -out iag.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo.iag.server"
# Websphere Liberty application server
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout tomcat.key -out liberty.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo.tomcat.server"
openssl pkcs12 -export -out tomcat.p12 -inkey liberty.key -in liberty.pem -passout pass:demokeystore
keytool -importcert -keystore tomcat.p12 -file iag.pem -alias isvajwt -storepass demokeystore -noprompt
# IBM Security Verify
echo -n | openssl s_client -connect $VERIFY_TENANT:443 | openssl x509 > verify_ca.pem
```

1. Deploy the Demo application with IBM Application Gateway\
Once the PKI and server xml configuration s defined; the resulting files can be added to a Kubernetes ConfigMap and 
deployed alongside the containers. The template yam files used for this use the `.tmpl` suffix; The `.macro_replace.sh` 
bash script is used to replace `%%MACRO%%` macros in the template files with the required configuration using Perl. 
There is a trick to this where the indentation when adding the values to the template files must match the expected 
yaml indentation.

