#!/usr/bin/env bash
set -eu -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"/..

kubectl apply -f $ROOT/examples/xnamespace
kubectl wait --for=condition=Ready namespaces.eaas.konflux-ci.dev/my-namespace-1.0
kubectl get secret/my-namespace-1.0-secret
kubectl delete -f $ROOT/examples/xnamespace
kubectl wait --for=delete objects --all --timeout=3m
