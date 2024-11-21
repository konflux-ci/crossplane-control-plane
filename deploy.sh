#!/usr/bin/env bash
set -eu -o pipefail

TARGET="${TARGET:=k8s}"

kustomize build --enable-helm crossplane/$TARGET | kubectl apply -f -

kubectl wait --for=condition=Available deployment -n crossplane-system --all --timeout=30s

kubectl apply -k config/$TARGET
