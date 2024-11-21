# crossplane-control-plane
This repository contains all configuration needed to setup crossplane for use
with Konflux.

# Installation

The quickest way to install everything is to run the `deploy.sh` script.

```bash
./deploy.sh # Deploy to k8s

TARGET=ocp ./deploy.sh # Deploy to ocp
```

This will install crossplane from a helm chart and then deploy our control plane
configuration.


## Crossplane Helm Chart

Here we have used Kustomization's Helm Chart Inflation Generator to install crossplane.

To install on kubernetes use the manifests located in `crossplane/k8s`:

```bash
kustomize build --enable-helm crossplane/k8s | kubectl apply -f -
```

To install on OpenShift use the manifests located in `crossplane/ocp`:

```bash
kustomize build --enable-helm crossplane/ocp | kubectl apply -f -
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

To deploy the configs on kubernetes use the manifests located in `config/k8s`:

```bash
kubectl apply -k config/k8s
```

To deploy the configs on OpenShift use the manifests located in `config/ocp`:

```bash
kubectl apply -k config/ocp
```

# Cleanup

```bash
./cleanup.sh # Cleanup for k8s

TARGET=ocp ./cleanup.sh # Cleanup for ocp
```
