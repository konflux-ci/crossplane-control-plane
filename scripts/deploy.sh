#!/usr/bin/env bash
set -eu -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"/..

kustomize build --enable-helm $ROOT/crossplane/ | kubectl apply -f -
kubectl wait --for=condition=Available deployment -n crossplane-system --all --timeout=30s

kubectl apply -k $ROOT/config/
kubectl wait --for=condition=Healthy functions,providers --all --timeout=30s
