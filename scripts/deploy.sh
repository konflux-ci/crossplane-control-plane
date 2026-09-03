#!/usr/bin/env bash
set -eu -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"/..

cat <<'EOF' >&2
Warning: Do not run deploy.sh or apply manifests under examples/ in a production environment.
This script applies example ProviderConfigs and cluster-scoped RBAC for local/CI testing only.
EOF

if [[ "${CI:-}" != "true" ]]; then
  read -r -p "Type 'yes' to continue: " reply
  if [[ "$reply" != "yes" ]]; then
    echo "Aborted." >&2
    exit 1
  fi
fi

kustomize build --enable-helm $ROOT/crossplane/ | kubectl apply -f -
kubectl wait --for=condition=Available deployment -n crossplane-system --all --timeout=120s

kubectl apply -k $ROOT/config/
kubectl wait --for=condition=Healthy functions,providers --all --timeout=120s

kubectl apply -k $ROOT/examples/provider-kubernetes-in-cluster

