#!/usr/bin/env bash
set -eu -o pipefail

kustomize build --enable-helm crossplane/ | kubectl apply -f -

kubectl wait --for=condition=Available deployment -n crossplane-system --all --timeout=30s

kubectl apply -k config/
