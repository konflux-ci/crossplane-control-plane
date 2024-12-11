# crossplane-control-plane
This repository contains all configuration needed to setup crossplane for use
with Konflux.

# Installation

The quickest way to install everything is to run the `deploy.sh` script.

```bash
./deploy.sh
```

This will install crossplane from a helm chart and then deploy our control plane
configuration.


## Crossplane Helm Chart

Here we have used Kustomization's Helm Chart Inflation Generator to install crossplane.

```bash
kustomize build --enable-helm crossplane/ | kubectl apply -f -
```

This installs crossplane version 1.18.0 in the `crossplane-system` namespace.

> **_Note_:**
If you are using kind cluster then you need to pull the crossplane image locally first
and then load the image into the kind cluster

```bash
docker pull crossplane/crossplane:v1.18.0
kind load docker-image crossplane/crossplane:v1.18.0 --name crossplane
```

## Control Plane Configuration

```bash
kubectl apply -k config/
```

# Cleanup

```bash
./cleanup.sh
```

# CompositeResourceDefinitions (XRDs)

## xnamespaces.eaas.konflux-ci.dev

Provides a kubernetes namespace for deploying and testing software.

### Prerequisites

- A `ProviderConfig` named `eaas-kubernetes-provider-config` referencing a secret with the keys:
  - `apiserver`: The URL of the kubernetes API server
  - `kubeconfig`: A valid kubeconfig for authenticating to the cluster
- The account associated with the kubeconfig must be granted full control of:
    - `LimitRanges`
    - `Namespaces`
    - `NetworkPolicies`
    - `ResourceQuotas`
    - `RoleBindings`
    - `Secrets`
    - `ServiceAccounts`
- The account must also be granted the `edit` ClusterRole.

All of this is configured in an example which sets up the kubernetes provider
to interact with the local cluster.

```bash
kubectl apply -k examples/provider-kubernetes-in-cluster
```

### Usage

See the [examples](./examples/xnamespace/).
