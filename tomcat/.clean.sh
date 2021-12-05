#!/bin/bash

ant clean

mvn clean

rm -f *.p12 *.key *.pem *.war

kubectl delete deployment iag tomcat-integration
kubectl delete service demo-iag-server demo-tomcat-server
kubectl delete configmap ibm-verify-tomcat-integration-config tomcat-config
kubectl delete secret ibm-verify-oidc-integration iag-login
