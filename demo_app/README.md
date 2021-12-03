# IBM Security Integration demo webapplication
This repo contains the source code for the JSP demonstration application used for SSO integrations with IBM Security 
Verify and IBM Security Verify Access.


This application is packaged into a demo WAR file which can be downloaded from the 
[releases](https://github.com/IBM-Security/ibm-security-integrations/releases) page.


## Project structure
The project is a web aplication, where the JSP content is in the `web` directory. Different integration targets require 
different content in the `WEB-INF` directory; therefore each target has its own directory prefixed with the target name. 
Current suppored targets are:
* Liberty: `LIBERTY-WEB-INF`
* JBoss / Wildfly: `JBOSS-WEB-INF`


## Building
This project is built using the Apache Ant build system. There are no external dependencies.

`ant build`
