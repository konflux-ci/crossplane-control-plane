---
name: adding-xrd-composition
description: Use when adding a new XRD, Composition, claim type, or Go-template pipeline under config/, or when a Crossplane feature needs xrd.yaml, composition.yaml, templates, examples, and a test script.
---

# Adding an XRD/Composition

## Overview

New Crossplane APIs in this repo require coordinated changes across `config/`, `config/functions.yaml`, `examples/`, and `scripts/`. Copy an existing XRD:

- `config/xnamespace/` — go-templating pipeline, inline connection details, auto-ready
- `config/xtestplatformcluster/` — go-templating + `function-patch-and-transform` for connection secrets, observe/report templates, auto-ready

`./scripts/deploy.sh` also applies `examples/provider-kubernetes-in-cluster/` (ProviderConfig + RBAC). Claims that compose in-cluster Kubernetes resources depend on this.

## Checklist

Copy and track progress:

```
- [ ] config/<name>/xrd.yaml
- [ ] config/<name>/composition.yaml
- [ ] config/<name>/kustomization.yaml
- [ ] config/<name>/templates/*.yaml
- [ ] config/functions.yaml — volumeMount + volume on DeploymentRuntimeConfig
- [ ] config/kustomization.yaml — add config/<name>/
- [ ] examples/<name>/ (claim.yaml and any prerequisite manifests)
- [ ] scripts/test-<plural-or-descriptive-name>.sh
- [ ] kustomize build config/ succeeds
- [ ] kind deploy + test script pass
```

## Step 1: Create config/<name>/

### xrd.yaml

Define `CompositeResourceDefinition` with group, composite kind/plural, claim kind/plural, and OpenAPI schema. Add `connectionSecretKeys` when the composition writes connection secrets (see `config/xtestplatformcluster/xrd.yaml`). See `config/xnamespace/xrd.yaml` for a minimal example.

### composition.yaml

Use `mode: Pipeline`. Typical steps:

- `function-go-templating` with `source: FileSystem` — `fileSystem.dirPath` is a **file** path under `/templates/<name>/` (e.g. `/templates/xnamespace/ns.yaml`)
- `function-go-templating` with `source: Inline` — for small templates like connection details (`config/xnamespace/composition.yaml`)
- `function-patch-and-transform` — when mapping composed resource connection secrets to the claim (`config/xtestplatformcluster/composition.yaml`)
- `function-auto-ready` — always last

Set `writeConnectionSecretsToNamespace: crossplane-connections` when emitting connection details.

### kustomization.yaml

```yaml
resources:
  - xrd.yaml
  - composition.yaml
configMapGenerator:
  - name: <name>-templates
    namespace: crossplane-system
    files:
      - templates/<file>.yaml
generatorOptions:
  disableNameSuffixHash: true
```

ConfigMap name must match the volume reference in `config/functions.yaml` (e.g. `xnamespace-templates` for `config/xnamespace/`).

### templates/

Go templates mounted into the function runtime via ConfigMap. The `dirPath` prefix must match the `mountPath` in `config/functions.yaml`.

## Step 2: Wire templates into functions.yaml

In `DeploymentRuntimeConfig` metadata.name `function-runtime-config`, add volume mounts to the shared `package-runtime` container (used by all functions via `runtimeConfigRef`):

```yaml
volumeMounts:
  - mountPath: /templates/<name>
    name: <name>-templates
    readOnly: true
volumes:
  - name: <name>-templates
    configMap:
      name: <name>-templates
```

## Step 3: Register in config/kustomization.yaml

Add `- <name>/` under `resources:` (alongside `xnamespace/`, `xtestplatformcluster/`).

## Step 4: Examples

Create `examples/<name>/` using the **claim** kind from the XRD `claimNames` (not the composite kind). Match `metadata.name` to what the test script expects.

- Minimal: `examples/xnamespace/claim.yaml` only
- With prerequisites: `examples/xtestplatformcluster/claim.yaml` + `namespaces.yaml`

Apply the whole directory in tests: `kubectl apply -f "$ROOT/examples/<name>/"`.

## Step 5: Test script

Name by claim resource plural or descriptive name — config dir and script name may differ (e.g. `config/xnamespace/` → `scripts/test-xnamespaces.sh`).

```bash
#!/usr/bin/env bash
set -eu -o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"/..
source "$ROOT/scripts/debug-dump.sh"
claim_group="<claim-plural>.<group>"   # e.g. namespaces.eaas.konflux-ci.dev
claim_name="<claim-name>"
register_debug_dump "$claim_group" "$claim_name"

kubectl apply -f "$ROOT/examples/<name>/"
kubectl wait --for=condition=Ready "$claim_group/$claim_name" --timeout=3m
# assert secrets, conditions, or composed resources
kubectl delete -f "$ROOT/examples/<name>/"
kubectl wait --for=delete objects --all --timeout=3m
```

Use `scripts/test-xnamespaces.sh` as the minimal pattern. Use `scripts/test-xtestplatformcluster.sh` when external CRDs, extra namespaces, or status simulation are required (cleanup may use `objects.kubernetes.crossplane.io` instead of `objects`).

## Constraints

- Packages only from [konflux-ci/crossplane-components](https://github.com/konflux-ci/crossplane-components)
- OCI images by digest only (`@sha256:...`), never tags
- Sensitive values in `Secrets`, not ConfigMaps or inline YAML
- Add ArgoCD annotation where existing resources use it: `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true`

## Verify

```bash
kustomize build --enable-helm crossplane/ > /dev/null
kustomize build config/ > /dev/null
kind create cluster
./scripts/deploy.sh    # includes provider-kubernetes-in-cluster prerequisites
./scripts/test-<name>.sh
./scripts/cleanup.sh
```

Add the new test to `.github/workflows/ci.yaml` `deploy-test-cleanup` job if it should run in CI.

## Common mistakes

Observed from this repo's existing XRDs and test scripts:

| Mistake | Fix | Where seen |
|---------|-----|------------|
| Template path not found at runtime | Match `mountPath`, `configMapGenerator.name`, and composition `dirPath` | `config/functions.yaml`, `config/xnamespace/kustomization.yaml`, `config/xnamespace/composition.yaml` |
| Wrong `claim_group` format | Use `<claim-plural>.<group>` (e.g. `namespaces.eaas.konflux-ci.dev`) | `scripts/test-xnamespaces.sh`, `scripts/test-xtestplatformcluster.sh` |
| Forgot `config/kustomization.yaml` | Add `- <name>/` under `resources:` or the XRD is never deployed | `config/kustomization.yaml` |
| Test uses composite kind | Examples and tests use claim kind/plural from XRD `claimNames` | `config/xnamespace/xrd.yaml` vs `examples/xnamespace/claim.yaml` |
| Missing `disableNameSuffixHash` | Set `generatorOptions.disableNameSuffixHash: true` or ConfigMap name drift breaks volume refs | `config/xnamespace/kustomization.yaml`, `config/xtestplatformcluster/kustomization.yaml` |
