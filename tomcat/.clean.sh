#!/bin/bash

rm -f *.p12 *.key *.pem *.war

kubectl delete deployment iag tomcat-integration
kubectl delete service iag tomcat-integration
kubectl delete configmap ibm-verify-tomcat-integration-config tomcat-config
kubectl delete secret ibm-verify-oidc-integration iag-login
