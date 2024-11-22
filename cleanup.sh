#!/usr/bin/env bash
set -eu -o pipefail

TARGET="${TARGET:=k8s}"

kubectl delete --ignore-not-found -k config/$TARGET

kustomize build --enable-helm crossplane/$TARGET | kubectl delete --ignore-not-found -f -

kubectl get crds -o name | grep "\.crossplane\.io$" | xargs --no-run-if-empty kubectl delete
