# crossplane-control-plane
This repository contains all the config files needed for installing crossplane.

# Installation
Here we have used Kustomization's Helm Chart Inflation Generator to install crossplane.

To install on kubernetes use the config located in `config/k8s`:

```bash
kustomize build --enable-helm config/k8s | kubectl apply -f -
```

To install on OpenShift use the config located in `config/ocp`:

```bash
kustomize build --enable-helm config/ocp | kubectl apply -f -
```

This installs crossplane version 1.18.0 and creates namespaces `crossplane-system` and
`crossplane-connections`.

> **_Note_:**
If you are using kind cluster then you need to pull the crossplane image locally first
and then load the image into the kind cluster

```bash
docker pull crossplane/crossplane:v1.18.0
kind load docker-image crossplane/crossplane:v1.18.0 --name crossplane
```
