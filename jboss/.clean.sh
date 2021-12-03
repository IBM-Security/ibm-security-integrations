#!/bin/bash

rm -f *.p12 *.keystore *.key *.pem standalone.xml *.pub

kubectl delete deployment iag wildlfly-integration
kubectl delete service iag wildlfly-integration
kubectl delete configmap ibm-verify-liberty-integration-config wildfly-config
kubectl delete secret ibm-verify-oidc-integration iag-login
