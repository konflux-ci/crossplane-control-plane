#!/usr/bin/env bash
set -eu -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"/..
claim_name='tp-aws-cluster'

# Install the EphemeralCluster CRD
ephemeralcluster_crd='https://raw.githubusercontent.com/openshift/ci-tools/refs/heads/main/pkg/api/ephemeralcluster/v1/ci.openshift.io_ephemeralclusters.yaml'
curl -sSL "$ephemeralcluster_crd" | kubectl apply -f -
kubectl wait crd/ephemeralclusters.ci.openshift.io --for=condition=Established=true --for=condition=NamesAccepted=true

kubectl apply -f $ROOT/examples/xtestplatformcluster/namespaces.yaml

# Create a claim
kubectl apply -f $ROOT/examples/xtestplatformcluster/claim.yaml
kubectl wait xtestplatformclusters.ci.openshift.org -l "crossplane.io/claim-name=$claim_name" --for=condition=Ready=true --for=condition=Synced=true

# Notify that the ephemeral cluster is ready and set the kubeconfig
ec_patch='[{
    "op": "add",
    "path": "/status",
    "value": {
        "kubeconfig": "kubeconfig",
        "conditions": [{
            "type": "ClusterReady",
            "status": "True",
            "lastTransitionTime": "2025-05-28T12:12:12Z",
            "reason": "",
            "message": ""
        }],
        "phase": "Ready"
    }
}]'

kubectl wait objects.kubernetes.crossplane.io -l "crossplane.io/claim-name=$claim_name" --for=condition=Ready=true --for=condition=Synced=true --timeout=3m
ephemeralcluster="$(kubectl get objects.kubernetes.crossplane.io -l "crossplane.io/claim-name=$claim_name" -o jsonpath='{.items[0].spec.forProvider.manifest.metadata.name}')"
kubectl -n ephemeral-cluster patch ephemeralclusters.ci.openshift.io/"$ephemeralcluster" --type=json -p="$ec_patch"

# Wait for the EphemeralCluster's conditions to be propagated to both the Composite Resource and Claim
kubectl wait xtestplatformclusters.ci.openshift.org -l "crossplane.io/claim-name=$claim_name" --for=condition=ClusterReady=true --timeout=3m
kubectl wait testplatformclusters.ci.openshift.org/"$claim_name" --for=condition=ClusterReady=true --timeout=3m

# Wait for the kubeconfig to be bound to the claim's secret
kubeconfig_secret="$(kubectl get testplatformclusters.ci.openshift.org/"$claim_name" -o jsonpath='{.spec.writeConnectionSecretToRef.name}')"
kubectl wait secret/"$kubeconfig_secret" --for=jsonpath='.data.kubeconfig' --timeout=3m

# Make sure the kubeconfig secret holds the right value
got_kubeconfig="$(kubectl get secret/"$kubeconfig_secret" -o jsonpath='{.data.kubeconfig}')"
want_kubeconfig='a3ViZWNvbmZpZw=='

if [ "$want_kubeconfig" != "$got_kubeconfig" ]; then
    echo "want kubeconfig '$want_kubeconfig' but got '$got_kubeconfig'"
    exit 1
fi

# Clean everything up
kubectl delete -f $ROOT/examples/xtestplatformcluster
kubectl wait objects.kubernetes.crossplane.io --for=delete --all --timeout=3m
