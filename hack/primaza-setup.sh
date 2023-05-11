#!/bin/env sh
#
# Setup Primaza MVP

set -e

# Constants
CLUSTER_MAIN=main
CLUSTER_WORKER=worker

[ -z "$KUBECONFIG" ] && KUBECONFIG=/tmp/kc-mvp-primaza

CLUSTER_MAIN_CONTEXT=kind-$CLUSTER_MAIN
CLUSTER_WORKER_CONTEXT=kind-$CLUSTER_WORKER

TENANT=mytenant
SERVICE_NAMESPACE=services
APPLICATION_NAMESPACE=applications
CLUSTER_ENVIRONMENT=worker


create_primaza_tenant() {
    until ./bin/primazactl create tenant "primaza-$TENANT" \
        --version "latest" \
        --context "$CLUSTER_MAIN_CONTEXT" \
        --kubeconfig "$KUBECONFIG"
    do
        printf "retrying applying primaza's manifests for tenant %s...\n" "$TENANT"
        sleep 5
    done
}

join_and_configure_worker() {
    ## Setup Primaza user
    until ./bin/primazactl join cluster \
        --version "latest" \
        --cluster-environment "$CLUSTER_ENVIRONMENT" \
        --environment "dev" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG" \
        --tenant-context "$CLUSTER_MAIN_CONTEXT" \
        --tenant-kubeconfig "$KUBECONFIG" \
        --tenant "primaza-$TENANT"
    do
        printf "retrying joining worker...\n"
        sleep 5
    done

    # scaffold application namespace "applications"
    until KUBECONFIG=$KUBECONFIG ./bin/primazactl create application-namespace "$APPLICATION_NAMESPACE" \
        --version "latest" \
        --cluster-environment "$CLUSTER_ENVIRONMENT" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --tenant-context "$CLUSTER_MAIN_CONTEXT" \
        --tenant "primaza-$TENANT"
    do
        printf "retrying creating application namespace %s...\n" "$APPLICATION_NAMESPACE"
        sleep 5
    done

    ## scaffold service namespace "services"
    until KUBECONFIG=$KUBECONFIG ./bin/primazactl create service-namespace "$SERVICE_NAMESPACE" \
        --version "latest" \
        --cluster-environment "$CLUSTER_ENVIRONMENT" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --tenant-context "$CLUSTER_MAIN_CONTEXT" \
        --tenant "primaza-$TENANT"
    do
        printf "retrying creating service namespace %s...\n" "$SERVICE_NAMESPACE"
        sleep 5
    done
}

