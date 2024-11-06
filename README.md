# crossplane-control-plane
This repository contains all the config files needed for installing crossplane.

# Installation
Here we have used Kustomization's Helm Chart Inflation Generator to install crossplane.
To install locally, use the below command:

```bash
cd config
kustomize build --enable-helm | kubectl apply -f -
```

This installs crossplane version 1.18.0 and creates namespaces crossplane-system and
crossplane-connections.

# Note
If you are using kind cluster then you need to pull the crossplane image locally first
and then load the image into the kind cluster

```bash
docker pull crossplane/crossplane:v1.18.0
kind load docker-image crossplane/crossplane:v1.18.0 --name crossplane
```
