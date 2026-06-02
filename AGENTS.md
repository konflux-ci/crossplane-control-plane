# Agent Guidelines for crossplane-control-plane

## Project Overview

Configuration for deploying Crossplane core controllers, functions, providers, XRDs,
and compositions for use within Konflux.

## Project Structure
- `crossplane/`             - Helm chart for Crossplane core (kustomize + helm inflation)
- `config/`                 - Providers, functions, XRDs, and compositions (deployed via kustomize)
- `config/<xrd>/templates/` - Go templates mounted into the function runtime as `ConfigMaps`
- `examples/`               - Example claims, prerequisite ProviderConfigs and RBAC configuration
- `scripts/`                - Deploy, test, and cleanup scripts

## Development

- Only utilize Crossplane helm charts, providers and functions packaged by the
  https://github.com/konflux-ci/crossplane-components repository.
- Only use OCI images referenced by digest, never by tag.
- Always store sensitive composition resources in `Secrets`.

### How to Add a New XRD/Composition
- Create `xrd.yaml`, `composition.yaml`, `kustomization.yaml`, and `templates/` within `config/<name>/`.
- Add the templates volume mount in `config/functions.yaml` (`DeploymentRuntimeConfig`)
- Add the new directory to `config/kustomization.yaml`
- Create an example claim in `examples/<name>/`
- Create a test script in `scripts/`

## AI Skills

Repo-specific skills live in `skills/`, symlinked for Claude Code (`.claude/skills`) and Cursor (`.cursor/skills`).

- [adding-xrd-composition](skills/adding-xrd-composition/SKILL.md) — checklist for new XRDs, compositions, templates, examples, and test scripts

## Verifying Changes

All tests require a kubernetes cluster. There are no unit tests.

```
kind create cluster                    # create a kind cluster
./scripts/deploy.sh                    # deploy everything
./scripts/test-xnamespaces.sh          # run XNamespace tests 
./scripts/test-xtestplatformcluster.sh # run XTestPlatform tests
./scripts/cleanup.sh                   # cleanup everything
```

