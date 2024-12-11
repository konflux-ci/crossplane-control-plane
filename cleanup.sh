#!/usr/bin/env bash
set -eu -o pipefail

kubectl delete --ignore-not-found -k config/

kustomize build --enable-helm crossplane/ | kubectl delete --ignore-not-found -f -

kubectl get crds -o name | grep "\.crossplane\.io$" | xargs --no-run-if-empty kubectl delete
