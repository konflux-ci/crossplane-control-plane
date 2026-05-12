#!/usr/bin/env bash
set -eu -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"/..
source "$ROOT/scripts/debug-dump.sh"
claim_group="namespaces.eaas.konflux-ci.dev"
claim_name="my-namespace-1.0"
register_debug_dump "$claim_group" "$claim_name"

kubectl apply -f $ROOT/examples/xnamespace
kubectl wait --for=condition=Ready "$claim_group"/"$claim_name" --timeout=3m
kubectl get secret/"$claim_name"-secret
kubectl delete -f $ROOT/examples/xnamespace
kubectl wait --for=delete objects --all --timeout=3m
