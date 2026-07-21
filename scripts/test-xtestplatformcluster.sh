#!/usr/bin/env bash
set -eu -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"/..
source "$ROOT/scripts/debug-dump.sh"
claim_group="testplatformclusters.ci.openshift.org"
xr_group="xtestplatformclusters.ci.openshift.org"
ec_group="ephemeralclusters.ci.openshift.io"
claim_name="tp-aws-cluster"
claim_label="crossplane.io/claim-name=$claim_name"
register_debug_dump "$claim_group" "$claim_name"

wait_timeout_secs=180
wait_timeout="${wait_timeout_secs}s"

# kubectl wait with -l exits immediately when no resources match yet; poll first.
wait_until_exists() {
    local deadline=$((SECONDS + wait_timeout_secs))
    local names=""

    while (( SECONDS < deadline )); do
        names="$(kubectl get "$@" -o name 2>/dev/null || true)"
        if [[ -n "$names" ]]; then
            return 0
        fi
        sleep 1
    done
    echo "timed out waiting for: kubectl get $*"
    return 1
}

# Install the EphemeralCluster CRD
ephemeralcluster_crd='https://raw.githubusercontent.com/openshift/ci-tools/refs/heads/main/pkg/api/ephemeralcluster/v1/ci.openshift.io_ephemeralclusters.yaml'
curl -sSL "$ephemeralcluster_crd" | kubectl apply -f -
kubectl wait crd/"$ec_group" --for=condition=Established=true --for=condition=NamesAccepted=true

kubectl apply -f "$ROOT"/examples/xtestplatformcluster/namespaces.yaml
kubectl apply -f "$ROOT"/examples/xtestplatformcluster/environment-config.yaml

# Create a claim
kubectl apply -f "$ROOT"/examples/xtestplatformcluster/claim.yaml
wait_until_exists $xr_group -l "$claim_label"
kubectl wait $xr_group -l "$claim_label" --for=condition=Synced=true --timeout="$wait_timeout"

ephemeralcluster="$(kubectl get $xr_group -l "$claim_label" -o jsonpath='{.items[0].metadata.name}')"
credentials_obj="objects.kubernetes.crossplane.io/credentials-${ephemeralcluster}"

wait_until_exists -n ephemeral-cluster "$ec_group/$ephemeralcluster"

# Simulate what the EphemeralCluster controller does: create a credentials Secret and set secretRef in the EphemeralCluster status.
test_kubeconfig=$(cat "$ROOT/scripts/testdata/test-kubeconfig.yaml")
kubectl -n ephemeral-cluster create secret generic test-credentials \
    --from-literal=kubeconfig="$test_kubeconfig" \
    --from-literal=kubeAdminPassword="admin"

# Status is a subresource; JSON-patching /status on the main resource is silently ignored once
# provider-kubernetes owns the object. Use server-side apply on the status subresource instead.
kubectl apply --server-side --subresource=status --force-conflicts -f - <<EOF
apiVersion: ci.openshift.io/v1
kind: EphemeralCluster
metadata:
  name: ${ephemeralcluster}
  namespace: ephemeral-cluster
status:
  secretRef: test-credentials
  phase: Ready
  prowJobURL: https://prowjob.fake
  conditions:
  - type: ClusterReady
    status: "True"
    lastTransitionTime: "2025-05-28T12:12:12Z"
EOF

# Composition initially renders credentials against secret name "pending" until it observes secretRef.
kubectl wait "$credentials_obj" \
    --for=jsonpath='{.spec.forProvider.manifest.metadata.name}'=test-credentials \
    --timeout="$wait_timeout"

# Wait for the EphemeralCluster's conditions to be propagated to both the Composite Resource and Claim
kubectl wait $xr_group -l "$claim_label" --for=condition=ClusterReady=true --for=condition=Ready=true --timeout="$wait_timeout"
kubectl wait $claim_group/"$claim_name" --for=condition=ClusterReady=true --timeout="$wait_timeout"

# Wait for the cluster credentials to be bound to the claim's secret
cluster_secret="$(kubectl get $claim_group/"$claim_name" -o jsonpath='{.spec.writeConnectionSecretToRef.name}')"
kubectl wait secret/"$cluster_secret" --for=jsonpath='.data.kubeconfig' --timeout="$wait_timeout"

# Make sure the cluster secret holds the right kubeconfig
got_kubeconfig="$(kubectl get secret/"$cluster_secret" -o jsonpath='{.data.kubeconfig}')"
want_kubeconfig=$(echo -n "$test_kubeconfig" | base64 -w0)

if [ "$want_kubeconfig" != "$got_kubeconfig" ]; then
    echo "want kubeconfig '$want_kubeconfig' but got '$got_kubeconfig'"
    exit 1
fi

# Make sure the cluster secret holds the right password
got_passwd="$(kubectl get secret/"$cluster_secret" -o jsonpath='{.data.kubeAdminPassword}')"
want_passwd='YWRtaW4='

if [ "$want_passwd" != "$got_passwd" ]; then
    echo "want kubeAdminPassword '$want_passwd' but got '$got_passwd'"
    exit 1
fi

# Make sure that `.status.phase` is being reported as a condition
got_ec_phase="$(kubectl get $claim_group/"$claim_name" -o go-template-file=<(echo '{{range .status.conditions}}{{if eq .type "_EphemeralClusterPhase"}}{{.message}}{{end}}{{end}}'))"
want_ec_phase='Ready'

if [ "$want_ec_phase" != "$got_ec_phase" ]; then
    echo "want ec phase '$want_ec_phase' but got '$got_ec_phase'"
    exit 1
fi

# Make sure that `.status.prowJobURL` is being reported as a condition
got_pjurl="$(kubectl get $claim_group/"$claim_name" -o go-template-file=<(echo '{{range .status.conditions}}{{if eq .type "_ProwJobURL"}}{{.message}}{{end}}{{end}}'))"
want_pjurl='https://prowjob.fake'

if [ "$want_pjurl" != "$got_pjurl" ]; then
    echo "want prowJobURL '$want_pjurl' but got '$got_pjurl'"
    exit 1
fi

# Make sure the EphemeralCluster has the konflux-tenant annotation set to the claim namespace
got_tenant="$(kubectl -n ephemeral-cluster get "$ec_group/$ephemeralcluster" -o jsonpath='{.metadata.annotations.ephemeralcluster\.ci\.openshift\.io/konflux-tenant}')"
want_tenant='default'

if [ "$want_tenant" != "$got_tenant" ]; then
    echo "want konflux-tenant annotation '$want_tenant' but got '$got_tenant'"
    exit 1
fi

# Make sure the EphemeralCluster has the konflux-cluster annotation set to the EnvironmentConfig cluster name
got_cluster="$(kubectl -n ephemeral-cluster get "$ec_group/$ephemeralcluster" -o jsonpath='{.metadata.annotations.ephemeralcluster\.ci\.openshift\.io/konflux-cluster}')"
want_cluster='test-cluster'

if [ "$want_cluster" != "$got_cluster" ]; then
    echo "want konflux-cluster annotation '$want_cluster' but got '$got_cluster'"
    exit 1
fi

got_pipelinerun_name="$(kubectl -n ephemeral-cluster get "$ec_group/$ephemeralcluster" -o jsonpath='{.metadata.annotations.ephemeralcluster\.ci\.openshift\.io/pipeline-run-name}')"
want_pipelinerun_name='foo'
if [ "$want_pipelinerun_name" != "$got_pipelinerun_name" ]; then
    echo "want PipelineRun name '$want_pipelinerun_name' but got '$got_pipelinerun_name'"
    exit 1
fi

got_taskrun_name="$(kubectl -n ephemeral-cluster get "$ec_group/$ephemeralcluster" -o jsonpath='{.metadata.annotations.ephemeralcluster\.ci\.openshift\.io/task-run-name}')"
want_taskrun_name='bar'
if [ "$want_taskrun_name" != "$got_taskrun_name" ]; then
    echo "want TaskRun name '$want_taskrun_name' but got '$got_taskrun_name'"
    exit 1
fi

# Clean everything up
kubectl delete -f "$ROOT"/examples/xtestplatformcluster
kubectl wait objects.kubernetes.crossplane.io --for=delete --all --timeout="$wait_timeout"
