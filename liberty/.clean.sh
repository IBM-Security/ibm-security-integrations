#!/bin/bash

rm -f *.p12 *.key *.pem *.war

kubectl delete deployment iag liberty-integration
kubectl delete service iag liberty-integration
kubectl delete configmap ibm-verify-liberty-integration-config liberty-config
kubectl delete secret ibm-verify-oidc-integration iag-login
