#!/usr/bin/env bash
#
# Shared debug dump helper for Crossplane integration tests.
# Source this file and call register_debug_dump to get a diagnostic
# dump on test failure.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")"/debug-dump.sh
#   register_debug_dump "testplatformclusters.ci.openshift.org" "tp-aws-cluster"
#

_DEBUG_DUMP_CLAIM_TYPE=""
_DEBUG_DUMP_CLAIM_NAME=""
_DEBUG_DUMP_CLAIM_NAMESPACE=""
_LOG_TAIL_LINES=100

register_debug_dump() {
    _DEBUG_DUMP_CLAIM_TYPE="$1"
    _DEBUG_DUMP_CLAIM_NAME="$2"
    _DEBUG_DUMP_CLAIM_NAMESPACE="${3:-default}"
    trap '_dump_debug_info $?' EXIT
}

_section() {
    echo ""
    echo "--- $1 ---"
    echo ""
}

_dump_debug_info() {
    local exit_code=$1
    if [ "$exit_code" -eq 0 ]; then
        return
    fi

    local label="crossplane.io/claim-name=$_DEBUG_DUMP_CLAIM_NAME"

    echo ""
    echo "================================================================================"
    echo "DEBUG DUMP (test failed with exit code $exit_code)"
    echo "================================================================================"

    _dump_claim
    _dump_composite_resources "$label"
    _dump_managed_objects "$label"
    _dump_connection_secrets
    _dump_events
    _dump_crossplane_pod_logs

    echo ""
    echo "================================================================================"
    echo "END DEBUG DUMP"
    echo "================================================================================"
}

_dump_claim() {
    _section "Claim ($_DEBUG_DUMP_CLAIM_TYPE/$_DEBUG_DUMP_CLAIM_NAME)"
    kubectl describe "$_DEBUG_DUMP_CLAIM_TYPE"/"$_DEBUG_DUMP_CLAIM_NAME" \
        -n "$_DEBUG_DUMP_CLAIM_NAMESPACE" 2>/dev/null || echo "  (not found)"
}

_dump_composite_resources() {
    local label=$1
    _section "Composite Resources (XR)"
    kubectl describe composite -l "$label" 2>/dev/null || echo "  (none found)"
}

_dump_managed_objects() {
    local label=$1
    _section "Managed Objects (provider-kubernetes)"
    kubectl describe objects.kubernetes.crossplane.io -l "$label" 2>/dev/null || echo "  (none found)"
}

_dump_connection_secrets() {
    _section "Connection Secrets"

    local tpl
    printf -v tpl '{{range .items}} {{.metadata.name}} type={{.type}} keys=[{{range $k, $v := .data}}{{$k}} {{end}}]\n{{end}}'

    echo "Namespace: crossplane-connections"
    kubectl get secrets -n crossplane-connections -o go-template="$tpl" 2>/dev/null || echo "  (none)"
    echo ""

    echo "Namespace: $_DEBUG_DUMP_CLAIM_NAMESPACE"
    kubectl get secrets -n "$_DEBUG_DUMP_CLAIM_NAMESPACE" -o go-template="$tpl" 2>/dev/null || echo "  (none)"
}

_dump_events() {
    _section "Events"
    for ns in "$_DEBUG_DUMP_CLAIM_NAMESPACE" crossplane-system crossplane-connections; do
        echo "Namespace: $ns"
        kubectl get events -n "$ns" --sort-by='.lastTimestamp' 2>/dev/null || echo "  (no events or namespace does not exist)"
        echo ""
    done
}

_dump_crossplane_pod_logs() {
    _section "Provider & Function Pod Logs (last $_LOG_TAIL_LINES lines each)"
    local pods=$(kubectl get pods -n crossplane-system -o name)
    for pod in $pods; do
        echo ">>> $pod"
        kubectl logs "$pod" -n crossplane-system --tail="$_LOG_TAIL_LINES" --all-containers 2>/dev/null || echo "  (failed to retrieve logs)"
        echo ""
    done
}
