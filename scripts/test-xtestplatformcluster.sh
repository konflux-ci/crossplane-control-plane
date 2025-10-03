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
        "kubeAdminPassword": "admin",
        "conditions": [{
            "type": "ClusterReady",
            "status": "True",
            "lastTransitionTime": "2025-05-28T12:12:12Z",
            "reason": "",
            "message": ""
        }],
        "prowJobURL": "https://prowjob.fake",
        "phase": "Ready"
    }
}]'

kubectl wait objects.kubernetes.crossplane.io -l "crossplane.io/claim-name=$claim_name" --for=condition=Ready=true --for=condition=Synced=true --timeout=3m
ephemeralcluster="$(kubectl get objects.kubernetes.crossplane.io -l "crossplane.io/claim-name=$claim_name" -o jsonpath='{.items[0].spec.forProvider.manifest.metadata.name}')"
kubectl -n ephemeral-cluster patch ephemeralclusters.ci.openshift.io/"$ephemeralcluster" --type=json -p="$ec_patch"

# Wait for the EphemeralCluster's conditions to be propagated to both the Composite Resource and Claim
kubectl wait xtestplatformclusters.ci.openshift.org -l "crossplane.io/claim-name=$claim_name" --for=condition=ClusterReady=true --timeout=3m
kubectl wait testplatformclusters.ci.openshift.org/"$claim_name" --for=condition=ClusterReady=true --timeout=3m

# Wait for the cluster credentials to be bound to the claim's secret
cluster_secret="$(kubectl get testplatformclusters.ci.openshift.org/"$claim_name" -o jsonpath='{.spec.writeConnectionSecretToRef.name}')"
kubectl wait secret/"$cluster_secret" --for=jsonpath='.data.kubeconfig' --timeout=3m

# Make sure the cluster secret holds the right kubeconfig
got_kubeconfig="$(kubectl get secret/"$cluster_secret" -o jsonpath='{.data.kubeconfig}')"
want_kubeconfig='a3ViZWNvbmZpZw=='

if [ "$want_kubeconfig" != "$got_kubeconfig" ]; then
    echo "want kubeconfig '$want_kubeconfig' but got '$got_kubeconfig'"
    exit 1
fi

# Make sure the cluster secret holds the right password
got_passwd="$(kubectl get secret/"$cluster_secret" -o jsonpath='{.data.kubeAdminPassword}')"
want_passwd='YWRtaW4='

if [ "$want_passwd" != "$got_passwd" ]; then
    echo "want kubeconfig '$want_passwd' but got '$got_passwd'"
    exit 1
fi

# Make sure the pr event headers holds the expected value
want_pr_event_headers='pr-event-headers'
got_pr_event_headers="$(kubectl get testplatformclusters.ci.openshift.org/"$claim_name" -o go-template-file=<(echo '{{ index .metadata.annotations "ephemeralcluster.ci.openshift.io/pr-event-headers" }}'))"

if [ "$want_pr_event_headers" != "$got_pr_event_headers" ]; then
    echo "want pr event headers '$want_pr_event_headers' but got '$got_pr_event_headers'"
    exit 1
fi

# Make sure the pr event payload holds the expected value
want_pr_event_payload='pr-event-payload'
got_pr_event_payload="$(kubectl get testplatformclusters.ci.openshift.org/"$claim_name" -o go-template-file=<(echo '{{ index .metadata.annotations "ephemeralcluster.ci.openshift.io/pr-event-payload" }}'))"

if [ "$want_pr_event_payload" != "$got_pr_event_payload" ]; then
    echo "want pr event payload '$want_pr_event_payload' but got '$got_pr_event_payload'"
    exit 1
fi

# Make sure that `.status.phase` is being reported as a condition
got_ec_phase="$(kubectl get testplatformclusters.ci.openshift.org/"$claim_name" -o go-template-file=<(echo '{{range .status.conditions}}{{if eq .type "_EphemeralClusterPhase"}}{{.message}}{{end}}{{end}}'))"
want_ec_phase='Ready'

if [ "$want_ec_phase" != "$got_ec_phase" ]; then
    echo "want ec phase '$want_ec_phase' but got '$got_ec_phase'"
    exit 1
fi

# Make sure that `.status.prowJobURL` is being reported as a condition
got_pjurl="$(kubectl get testplatformclusters.ci.openshift.org/"$claim_name" -o go-template-file=<(echo '{{range .status.conditions}}{{if eq .type "_ProwJobURL"}}{{.message}}{{end}}{{end}}'))"
want_pjurl='https://prowjob.fake'

if [ "$want_pjurl" != "$got_pjurl" ]; then
    echo "want prowJobURL '$want_pjurl' but got '$got_pjurl'"
    exit 1
fi

# Clean everything up
kubectl delete -f $ROOT/examples/xtestplatformcluster
kubectl wait objects.kubernetes.crossplane.io --for=delete --all --timeout=3m
