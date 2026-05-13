# crossplane-control-plane
This repository contains all configuration needed to setup crossplane for use with Konflux.

# Getting Started

The quickest way to get started is to run the `deploy.sh` script.

```bash
./scripts/deploy.sh
```

This deploys crossplane from a helm chart, all necessary providers and functions, and our XRD
configuration to a kubernetes/OpenShift cluster.

It also deploys some example ProviderConfigs and RBAC configuration necessary to test the compositions.
Refer to the [provider-kubernetes-in-cluster](./examples/provider-kubernetes-in-cluster/) example to
learn about these prerequisites.

All resources can be removed using the cleanup script.

```bash
./scripts/cleanup.sh
```

# CompositeResourceDefinitions (XRDs)

## xnamespaces.eaas.konflux-ci.dev

Provides a kubernetes namespace for deploying and testing software.

See [here](./examples/xnamespace/) for an example claim or run a test with it using:

```bash
./scripts/test-xnamespaces.sh
```

## xtestplatformcluster.ci.openshift.org

Provisions an ephemeral OpenShift cluster via OpenShift-CI infrastructure.

See [here](./examples/xtestplatformcluster/) for an example claim or run a test with it using:

```bash
./scripts/test-xtestplatformcluster.sh
```

