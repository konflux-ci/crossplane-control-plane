#!/usr/bin/env bash
set -eu -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"/..

kubectl delete --ignore-not-found -k $ROOT/config/

kustomize build --enable-helm $ROOT/crossplane/ | kubectl delete --ignore-not-found -f -

kubectl get crds -o name | grep "\.crossplane\.io$" | xargs --no-run-if-empty kubectl delete
