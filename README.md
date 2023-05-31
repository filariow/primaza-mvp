# Primaza MVP demo

In this repository you can find a set of scripts and config to create a multi-cluster environment for Primaza's MVP Demo and the demos in form of a go project.

The go project defines the following use cases:
* Multi-Cluster Primaza environment
* Manual Registration of a Service
* Discovering a Service
* 3rd-party integration
* Claiming from an Application Namespace
<!-- * Claiming from Primaza -->

# Run the demos

## Setup the Multi Cluster environment

Before setting up the multi-cluster environment, you need to configure your shell with required Environment Variables.
You can use the [./hack/configure-shell.sh](./hack/configure-shell.sh) script.
However, this script relies on Bitwarden cli (`bw`).
In case you are not using Bitwarden, have a llok at the script and set the needed environment variables.
Also, set the environment variable `SKIP_BITWARDEN=true`.

To setup a local environment for running the demos, please take a look at [./hack/setup.sh](./hack/setup.sh).
You can run the script by invoking it from the root folder (i.e. `./hack/setup.sh` or using `make setup`).
> If you are not using Bitwarden, set the environment variable `SKIP_BITWARDEN=true`.

The script will create 2 kind clusters (`main` and `worker`) and install the cert-manager on both.
Also, on the worker cluster, in the namespace `applications` it will install AWS Controllers for Kubernetes (ACK) and ArgoCD.

## The Primaza MVP Demo Book

Please refer to [The Primaza MVP Demo Book](https://primaza.io/mvp-demo/).
