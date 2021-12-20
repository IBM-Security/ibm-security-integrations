# IBM Security Verify SSO integration
This repo contains resources for integrating IBM Security Verify with OpenLiberty using IBM Application Gateway as a web 
reverse proxy to manage authentication and authorization. Identity is supplied to the OpenLiberty application server using 
a signed JWT.


## Prerequisites
* Kubernetes


## Demo Web Application
This deployment relies on the JSP application built in [this](../demo_app) directory, a compiled application is available 
from the [releases](https://github.com/IBM-Security/ibm-security-integrations/releases) tab. The Liberty application 
should be copied to an archive called `LIBERTY_SecTestWeb.war` to be compatible with the provided shell scripts.


## Domain name
The IBM Security Verify applicaiton must be configured with a redirect uri for the demo deployment. For this demo a [hosts 
file entry](https://en.wikipedia.org/wiki/Hosts_(file)) entry was used to set the kubernets cluster IPv4 address to route to
the `ibm.security.integration.demo` domain.


## Environment variables
- `CLIENT_SECRET`: IBM Security Verify application client secret
- `CLIENT_ID`: IBM Security Verify application client id
- `DOCKER_SECRET`: docker.hub password to fetch IBM Application Gateway container
- `DOCKER_ID`: docker.hub username to fetch IBM Application Gateway container
- `VERIFY_TENANT`: domain name of IBM Security Verify tenant


## Deploying
The deployment of this demonstration is broken into three steps:
1. Generate or request the required PKI\
For demonstration and testing, self signed certificates will suffice for securing connections between containers and IBM 
Security Verify.


```BASH
# IBM Application Gateway
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout iag.key -out iag.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo.iag.server"
# Websphere Liberty application server
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout liberty.key -out liberty.pem \
        -subj "/C=AU/ST=QLD/L=Gold Coast/O=IBM/CN=demo.liberty.server"
openssl pkcs12 -export -out liberty.p12 -inkey liberty.key -in liberty.pem -passout pass:demokeystore
keytool -importcert -keystore liberty.p12 -file iag.pem -alias isvajwt -storepass demokeystore -noprompt
# IBM Security Verify
echo -n | openssl s_client -connect $VERIFY_TENANT:443 | openssl x509 > verify_ca.pem
```

2. Deploy the Demo application with IBM Application Gateway\
Once the PKI and server xml configuration is defined; the resulting files can be added to a Kubernetes ConfigMap and 
deployed alongside the containers. The template yaml files used for this use the `.tmpl` suffix; The `.macro_replace.sh` 
bash script is used to replace `%%MACRO%%` macros in the template files with the required configuration using Perl. 
There is a trick to this where the indentation when adding the values to the template files must match the expected 
yaml indentation.


3. Test out the integration\
To test out the integration open a new web browser and navigate to https://ibm.security.integration.demo:30443/libertysso/DemoApplication
