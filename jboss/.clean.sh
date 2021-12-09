#!/bin/bash

rm -f *.p12 *.keystore *.key *.pem standalone.xml *.pub *.war

kubectl delete deployment iag-instance wildfly-integration
kubectl delete service iag-instance wildfly-integration
kubectl delete configmap ibm-verify-wildfly-integration-config wildfly-config
kubectl delete secret ibm-verify-oidc-integration iag-login
