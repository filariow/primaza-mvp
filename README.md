# Primaza MVP demo

In this repository you can find a set of scripts and configs to create a multi-cluster environment for Primaza's MVP Demo and the demos in form of a go project.

The go project defines the following use cases:
* Multi-Cluster Primaza environment
* Manual Registration of a Service
* Discovering a Service

Next to come:
* 3rd-party integration
* Claiming from Primaza
* Claiming from an Application Namespace

# Clone this repo

When cloning remember to include submodules

```
git clone --recurse-submodules https://filariow/primaza-mvp
```

or

```
gh repo clone filariow/primaza-mvp -- --recurse-submodules
```

# Run the demos

## Setup the Multi Cluster environment

To setup a local environment for running the demos, please take a look at [./hack/setup.sh](./hack/setup.sh).

The script will create 2 kind clusters (`main` and `worker`) and install the cert-manager on both.
Also, on the worker cluster it will install Operator Lifecycle Manager (OLM) and AWS Controllers for Kubernetes (ACK).

## Multi-Cluster Primaza Environment

This demo leverages on `primazactl` to create a Primaza Multi-Cluster environment.

## Manual Registration of a Service

This demo leverages on `aws` CLI to create an SQS Queue and manually register a RegisteredService in Primaza's Control Plane.
> requires to have already run the `multi-cluster primaza environment` demo

## Discovering a Service

This demo leverages on ACK for creating an RDS Postgres database and on Primaza discovering mechanism to discover it.
> requires to have already run the `multi-cluster primaza environment` demo
