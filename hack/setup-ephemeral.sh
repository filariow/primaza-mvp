#!/bin/env bash
#
# Setup Primaza MVP

set -e

LOCAL_VARIABLES_FILE="setup-local-vars.sh"
[ -s "$LOCAL_VARIABLES_FILE" ] && source "./setup-local-vars.sh"

[ -z "$AWS_RDS_PROD_DB_PASSWORD" ] && echo "Please set the AWS_RDS_PROD_DB_PASSWORD Environment Variable" && exit 1
[ -z "$AWS_RDS_TEST_DB_PASSWORD" ] && echo "Please set the AWS_RDS_TEST_DB_PASSWORD Environment Variable" && exit 1


## Defaulted inputs
[ -z "$KUBECONFIG" ] && KUBECONFIG="/tmp/kc-mvp-primaza"
[ -z "$SKIP_BITWARDEN" ] && SKIP_BITWARDEN="false"
[ -z "$SKIP_AWS" ] && SKIP_AWS="false"

# Constants
## Infra
CLUSTER_MAIN="main"
CLUSTER_WORKER="worker"
CLUSTER_MAIN_CONTEXT="kind-$CLUSTER_MAIN"
CLUSTER_WORKER_CONTEXT="kind-$CLUSTER_WORKER"

## Prod
APPLICATION_NAMESPACE_PROD="applications-prod"
SERVICE_NAMESPACE_PROD="services-prod"

## Test
APPLICATION_NAMESPACE_TEST="applications-test"
SERVICE_NAMESPACE_TEST="services-test"

## Cert Manager
CERTMANAGER_VERSION="v1.11.1"

## AWS Controllers for Kubernetes
AWS_REGION="us-east-2"
### prod
AWS_RDS_PROD_DB_NAME="postgres"
AWS_RDS_PROD_DBINSTANCE_NAME="rds-pmz-demo-eph-catalog-prod"
AWS_RDS_PROD_DB_REGION="eu-west-3"
AWS_RDS_PROD_DB_USERNAME="awsuser"
AWS_RDS_PROD_DB_SIZE="db.t4g.small"
AWS_RDS_PROD_DB_ENGINE="postgres"
### ephemeral
AWS_RDS_TEST_DB_NAME="postgres"
AWS_RDS_TEST_DBINSTANCE_NAME="rds-pmz-demo-eph-catalog-test"
AWS_RDS_TEST_DB_REGION="eu-west-3"
AWS_RDS_TEST_DB_USERNAME="awsuser"
AWS_RDS_TEST_DB_SIZE="db.t4g.small"
AWS_RDS_TEST_DB_ENGINE="postgres"

## ARGOCD
ARGOCD_WATCHED_REPO="https://github.com/filariow/primaza-mvp.git"
ARGOCD_WATCHED_REPO_FOLDER_PROD="config/ephemeral/prod/claiming"
ARGOCD_WATCHED_REPO_FOLDER_TEST="config/ephemeral/test/claiming"
ARGOCD_VERSION="v2.7.4"
ARGOCD_PORT_PROD="9000"
ARGOCD_PORT_TEST="9001"

## NGROK
NGROK_LOCAL_CONFIG_PATH="./hack/ngrok-ephemeral.yml"
NGROK_BASE_CONFIG_PATH="$HOME/.config/ngrok/ngrok.yml"


build_and_load_demo_app_images()
(
    docker tag ghcr.io/primaza/demo-app/frontend:{latest,latestknown} || true
    docker tag ghcr.io/primaza/demo-app/catalog:{latest,latestknown} || true
    docker tag ghcr.io/primaza/demo-app/catalog-init:{latest,latestknown} || true
    docker tag ghcr.io/primaza/demo-app/orders:{latest,latestknown} || true
    docker tag ghcr.io/primaza/demo-app/orders-init:{latest,latestknown} || true

    docker rmi ghcr.io/primaza/demo-app/frontend:latest || true
    docker rmi ghcr.io/primaza/demo-app/catalog:latest || true
    docker rmi ghcr.io/primaza/demo-app/catalog-init:latest || true
    docker rmi ghcr.io/primaza/demo-app/orders:latest || true
    docker rmi ghcr.io/primaza/demo-app/orders-init:latest || true

    docker pull ghcr.io/primaza/demo-app/frontend:latest
    docker pull ghcr.io/primaza/demo-app/catalog:latest
    docker pull ghcr.io/primaza/demo-app/catalog-init:latest
    docker pull ghcr.io/primaza/demo-app/orders:latest
    docker pull ghcr.io/primaza/demo-app/orders-init:latest

    kind load docker-image --name "$CLUSTER_WORKER" \
        ghcr.io/primaza/demo-app/{frontend,catalog,catalog-init,orders,orders-init}:latest
)

check_dependencies()
{
    err=0
    for i in "$@"
    do
        if ! command -v "$i" > /dev/null
        then
            printf "please install '%s'\n" "$i"
            err=$((err+1))
        fi
    done

    [ "$err" -eq "0" ] || exit 1
}

# AWS Services
create_aws_rds_prod()
{
    create_aws_rds \
        "$AWS_RDS_PROD_DBINSTANCE_NAME" \
        "$AWS_RDS_PROD_DB_REGION" \
        "$AWS_RDS_PROD_DB_SIZE" \
        "$AWS_RDS_PROD_DB_NAME" \
        "$AWS_RDS_PROD_DB_ENGINE" \
        "$AWS_RDS_PROD_DB_PASSWORD" \
        "$AWS_RDS_PROD_DB_USERNAME"
}

create_aws_rds_test()
{
    create_aws_rds \
        "$AWS_RDS_TEST_DBINSTANCE_NAME" \
        "$AWS_RDS_TEST_DB_REGION" \
        "$AWS_RDS_TEST_DB_SIZE" \
        "$AWS_RDS_TEST_DB_NAME" \
        "$AWS_RDS_TEST_DB_ENGINE" \
        "$AWS_RDS_TEST_DB_PASSWORD" \
        "$AWS_RDS_TEST_DB_USERNAME"
}

create_aws_rds()
{
    set -e

    if [ "$(aws rds describe-db-instances \
            --filters 'Name=db-instance-id,Values="'"$1"'"' \
            --region "$2" \
            --no-cli-pager | jq '.DBInstances | length')" = "0" ]; then
        aws rds create-db-instance \
            --db-instance-identifier "$1" \
            --db-instance-class "$3" \
            --db-name "$4" \
            --engine "$5" \
            --master-user-password "$6" \
            --master-username "$7" \
            --allocated-storage 20 \
            --region "$2" \
            --publicly-accessible \
            --no-cli-pager
    else
        aws rds modify-db-instance \
            --db-instance-identifier "$1" \
            --master-user-password "$6" \
            --region "$2" \
            --no-cli-pager
    fi

    group_id=$( aws rds describe-db-instances \
        --filters 'Name=db-instance-id,Values="'"$1"'"' \
        --region "$2" \
        --no-cli-pager | jq -r '.DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' )
    exist_inbound_rule=$( aws ec2 describe-security-group-rules \
        --filter 'Name="group-id",Values="'"$group_id"'"' \
        --region "$2" | \
        jq '[.SecurityGroupRules[] | select(.ToPort == 5432 and .CidrIpv4 == "0.0.0.0/0")] | length' )

    if [ "$exist_inbound_rule" == "0" ]
    then
        aws ec2 authorize-security-group-ingress \
            --group-id "$group_id" \
            --protocol "tcp" \
            --port "5432" \
            --cidr "0.0.0.0/0" \
            --region "$2" \
            --no-cli-pager
    fi
}


# Common
install_cert_manager()
{
    kubectl apply \
        -f "https://github.com/cert-manager/cert-manager/releases/download/$CERTMANAGER_VERSION/cert-manager.yaml" \
        --kubeconfig "$1" \
        --context "$2"
}

wait_rollouts() {
    kubectl rollout status \
        -n cert-manager deploy/cert-manager-webhook \
        -w --timeout=120s \
        --kubeconfig "$KUBECONFIG" \
        --context "$CLUSTER_MAIN_CONTEXT"

    kubectl rollout status \
        -n cert-manager deploy/cert-manager-webhook \
        -w --timeout=120s \
        --kubeconfig "$KUBECONFIG" \
        --context "$CLUSTER_WORKER_CONTEXT"
}

bake_external_kubeconfig()
{
    cluster=$1
    filepath="/tmp/kc-mvp-primaza-external-$1"

    ext_url=$( curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[] | select(.name == "'"$cluster"'") | .public_url' )
    printf "Creating Kubeconfig for '%s' (url: %s) cluster with external url at '%s'\n" "$cluster" "$ext_url" "$filepath"

    kind get kubeconfig --name "$cluster" | \
        sed 's/server: .*$/server: '"$( echo "$ext_url" | sed 's/https:\/\//http:\\\/\\\//g' )"'/' > "$filepath"
}

# Main Cluster
create_main_cluster()
{
    kind create cluster --name "$1" --kubeconfig "$2" # --image "kindest/node:v1.26.3"

    ## install cert-manager
    install_cert_manager "$2" "$3"

    configure_main_cluster
}

configure_main_cluster()
(
    # docker tag ghcr.io/primaza/primaza:latest ghcr.io/primaza/primaza:latestknown || true
    docker rmi ghcr.io/primaza/primaza:latest || true
    docker pull ghcr.io/primaza/primaza:v0.1.0
    docker tag ghcr.io/primaza/primaza:v0.1.0 ghcr.io/primaza/primaza:latest || true
    kind load docker-image ghcr.io/primaza/primaza:latest --name "$CLUSTER_MAIN"
)

# Worker Cluster
create_worker_cluster()
{
    kind create cluster --name "$1" --kubeconfig "$2" --config <( cat << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  # image: kindest/node:v1.26.3
  # port forward 80 on the host to 80 on this node
  extraPortMappings:
  - containerPort: 32080
    hostPort: 80
    protocol: TCP
  - containerPort: 32081
    hostPort: 8080
    protocol: TCP
EOF
)

    ## install cert-manager
    install_cert_manager "$2" "$3"

    configure_worker_cluster
}

configure_worker_cluster()
{
    # docker tag ghcr.io/primaza/primaza-agentapp:latest ghcr.io/primaza/primaza-agentapp:latestknown || true
    # docker tag ghcr.io/primaza/primaza-agentsvc:latest ghcr.io/primaza/primaza-agentsvc:latestknown || true

    docker rmi ghcr.io/primaza/primaza-agentapp:latest || true
    docker rmi ghcr.io/primaza/primaza-agentsvc:latest || true

    docker pull ghcr.io/primaza/primaza-agentapp:v0.1.0
    docker pull ghcr.io/primaza/primaza-agentsvc:v0.1.0

    docker tag ghcr.io/primaza/primaza-agentapp:v0.1.0 ghcr.io/primaza/primaza-agentapp:latest || true
    docker tag ghcr.io/primaza/primaza-agentsvc:v0.1.0 ghcr.io/primaza/primaza-agentsvc:latest || true

    kind load docker-image ghcr.io/primaza/primaza-agentapp:latest --name "$CLUSTER_WORKER"
    kind load docker-image ghcr.io/primaza/primaza-agentsvc:latest --name "$CLUSTER_WORKER"

    # kubectl apply -k 'https://github.com/argoproj/argo-cd/manifests/crds?ref=stable' \
    kubectl apply -f "config/argocd/crds.yaml" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"

    # pre-populate kind cache with images from host (reduce bandwidth consumption during live demo)
    build_and_load_demo_app_images
}

# Service Namespace
create_service_namespace()
{
    kubectl create namespace "$1" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG" \
        --dry-run=client --output=yaml | \
        kubectl apply -f - \
            --context "$CLUSTER_WORKER_CONTEXT" \
            --kubeconfig "$KUBECONFIG"

    [ "$SKIP_AWS" != "true" ] && {
        install_ack_controller \
            "sqs" \
            "$( curl -sL https://api.github.com/repos/aws-controllers-k8s/sqs-controller/releases/latest | grep '"tag_name":' | cut -d'"' -f4 | tr -d "v" )" \
            "$1"
    }
}

install_ack_controller()
{
    SERVICE=$1
    RELEASE_VERSION=$2
    NAMESPACE=$3

    aws ecr-public get-login-password --region us-east-1 | \
        helm registry login --username AWS --password-stdin public.ecr.aws

    helm install "ack-$SERVICE-controller-$NAMESPACE" \
        "oci://public.ecr.aws/aws-controllers-k8s/$SERVICE-chart" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --kubeconfig "$KUBECONFIG" \
        --kube-context "$CLUSTER_WORKER_CONTEXT" \
        --version="$RELEASE_VERSION" \
        --set=aws.region="$AWS_REGION" \
        --set=installScope=namespace

    kubectl set env "deployment/ack-$SERVICE-controller-$NAMESPACE-$SERVICE-chart" \
        AWS_ACCESS_KEY_ID="$( aws configure get aws_access_key_id )" \
        AWS_SECRET_ACCESS_KEY="$( aws configure get aws_secret_access_key )" \
        --namespace "$NAMESPACE" \
        --kubeconfig "$KUBECONFIG" \
        --context "$CLUSTER_WORKER_CONTEXT"
}

## Application Namespace
create_application_namespace()
{
    # install ArgoCD and NGINX Ingress
    install_argocd "$1"
    install_and_configure_nginx_ingress "$1" "$4" "$5" "$6"

    # defer ArgoCD configuration for performance reasons
    configure_argocd "$1" "$2" "$3" "$4"
}

install_argocd()
{
    # install ArgoCD
    kubectl create namespace "$1" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG" \
        --dry-run=client --output=yaml | \
        kubectl apply -f - \
            --context "$CLUSTER_WORKER_CONTEXT" \
            --kubeconfig "$KUBECONFIG"

   kubectl apply -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/namespace-install.yaml" \
        --namespace "$1" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"
}

configure_argocd()
{
    ARGO_SECRET=argocd-initial-admin-secret

    NAMESPACE="$1"
    ARGOCD_PORT="$2"
    ARGOCD_WATCHED_REPO_FOLDER="$3"
    ARGOCD_APP="demo-app-outer-loop-$4"

    echo "waiting for secret $ARGO_SECRET to be created..."
    until kubectl get secrets \
        "$ARGO_SECRET" \
        --namespace "$NAMESPACE" \
        --kubeconfig "$KUBECONFIG" \
        --context "$CLUSTER_WORKER_CONTEXT" &> /dev/null
    do
        sleep 5
    done
    echo "$ARGO_SECRET secret found..."

    until KUBECONFIG=$KUBECONFIG argocd login \
        --username admin \
        --password "$( argocd admin initial-password \
            --namespace "$NAMESPACE" \
            --kube-context "$CLUSTER_WORKER_CONTEXT" \
            --kubeconfig "$KUBECONFIG" | head -n 1 )" \
        --port-forward --port-forward-namespace "$NAMESPACE" --grpc-web \
        --insecure \
        --kube-context "$CLUSTER_WORKER_CONTEXT"; do
        sleep 2
    done

# shellcheck disable=SC2098
# shellcheck disable=SC2097
    until KUBECONFIG=$KUBECONFIG argocd cluster add --in-cluster --namespace "$NAMESPACE" "$CLUSTER_WORKER_CONTEXT" --yes \
        --port-forward --port-forward-namespace "$NAMESPACE" --grpc-web --insecure \
        --kube-context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"; do
        sleep 2
    done


    until KUBECONFIG=$KUBECONFIG argocd app create "$ARGOCD_APP" \
        --repo "$ARGOCD_WATCHED_REPO" \
        --path "$ARGOCD_WATCHED_REPO_FOLDER" \
        --dest-server "https://kubernetes.default.svc" \
        --dest-namespace "$NAMESPACE" \
        --kube-context "$CLUSTER_WORKER_CONTEXT" \
        --port-forward --port-forward-namespace "$NAMESPACE" --grpc-web \
        --insecure; do
        sleep 5
    done

    kubectl patch role argocd-application-controller \
        --type=merge \
        --patch-file <( cat << EOF
rules:
  - apiGroups:
    - "*"
    resources:
    - "*"
    verbs:
    - "*"
EOF
        ) \
        --namespace "$NAMESPACE" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"

    kubectl patch configmap argocd-cm \
        --patch-file <( cat << EOF
data:
  resource.customizations: |
    primaza.io/ServiceClaim:
       health.lua: |
        hs = {}
        hs.status = "Progressing"
        hs.message = ""

        if obj == nil or obj.status == nil then
          return hs
        end

        if obj.status.state == "Resolved" then
          hs.status = "Healthy"
          hs.message = "Bound RegisteredService: " .. obj.status.registeredService
        end
        return hs
    networking.k8s.io/Ingress:
       health.lua: |
        hs = {}
        hs.status = "healthy"
        return hs
EOF
        ) \
        --namespace "$NAMESPACE" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"

    argocd_password=$( argocd admin initial-password \
            --namespace "$NAMESPACE" \
            --kube-context "$CLUSTER_WORKER_CONTEXT" \
            --kubeconfig "$KUBECONFIG" | head -n 1 )

    if [ -n "$ARGOCD_PASSWORD" ]; then
        KUBECONFIG=$KUBECONFIG argocd account update-password \
            --account "admin" \
            --new-password "$ARGOCD_PASSWORD" \
            --current-password "$argocd_password" \
            --port-forward --port-forward-namespace "$NAMESPACE" --grpc-web \
            --insecure \
            --kube-context "$CLUSTER_WORKER_CONTEXT"
    else
        ARGOCD_PASSWORD="$argocd_password"
    fi

    [ "$SKIP_BITWARDEN" = "false" ] && {
        argocd_uri=$( curl -s http://localhost:4040/api/tunnels | jq '.tunnels[] | select(.name == "worker") | .public_url' -r )
        argocd_sec=$( bw get item argocd --session "$BW_SESSION" )
        argocd_sec_id=$( echo "$argocd_sec" | jq -r '.id' )
        [ -n "$argocd_sec_id" ] && \
                echo "$argocd_sec" | \
                    jq --arg v "$ARGOCD_PASSWORD" '.login.password=$v' | \
                    jq --arg v "$argocd_uri" '.login.uris[1].uri=$v' | \
                    bw encode | \
                    bw edit item "$argocd_sec_id" --session "$BW_SESSION"
    }

    # Expose ArgoCD
    printf "\nArgoCD Web UI is published at https://localhost:%s\nadmin account password: %s\n" "$ARGOCD_PORT" "$argocd_password"
    kubectl port-forward "services/argocd-server" "$ARGOCD_PORT:443" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --namespace "$NAMESPACE" \
        --kubeconfig "$KUBECONFIG" &> /dev/null &

}

install_and_configure_nginx_ingress()
{
    helm upgrade --install "ingress-nginx-$2" "ingress-nginx" \
        --repo "https://kubernetes.github.io/ingress-nginx" \
        --namespace "$1" --create-namespace \
        --kubeconfig "$KUBECONFIG" \
        --set "controller.ingressClassResource.name=nginx-$2"

    kubectl patch services "ingress-nginx-$2-controller"  --patch \
        '{ "spec": { "ports": [ { "appProtocol": "http", "name": "http", "nodePort": '"$3"', "port": 80, "protocol": "TCP", "targetPort": 80}, { "appProtocol": "https", "name": "https", "nodePort": '"$4"', "port": 443, "protocol": "TCP", "targetPort": 443 } ] } }' \
        --namespace "$1" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"
}

## Setup Primaza environment
setup_primaza_environment()
{
    make ephemeral-run-setup-env

    kubectl delete \
        validatingwebhookconfigurations.admissionregistration.k8s.io \
        validating-webhook-configuration \
        --kubeconfig "$KUBECONFIG" \
        --context "$CLUSTER_WORKER_CONTEXT"

    make ephemeral-run-services-demos

    NAMESPACE="applications-prod"
    ARGOCD_APP="demo-app-outer-loop-prod"

    KUBECONFIG=$KUBECONFIG argocd login \
        --username "admin" \
        --password "$ARGOCD_PASSWORD" \
        --port-forward --port-forward-namespace "$NAMESPACE" --grpc-web \
        --insecure \
        --kube-context "$CLUSTER_WORKER_CONTEXT"

    until KUBECONFIG=$KUBECONFIG argocd app sync "$ARGOCD_APP" \
        --kube-context "$CLUSTER_WORKER_CONTEXT" \
        --port-forward --port-forward-namespace "$NAMESPACE" --grpc-web \
        --insecure; do
        sleep 5
    done

    kubectl patch configmap argocd-cm \
        --patch-file <( cat << EOF
data:
  resource.customizations: |
    primaza.io/ServiceClaim:
       health.lua: |
        hs = {}
        hs.status = "Progressing"
        hs.message = ""

        if obj == nil or obj.status == nil then
          return hs
        end

        if obj.status.state == "Resolved" then
          hs.status = "Healthy"
          hs.message = "Bound RegisteredService: " .. obj.status.registeredService
        end
        return hs
    networking.k8s.io/Ingress:
       health.lua: |
        hs = {}
        hs.status = "healthy"
        return hs
EOF
        ) \
        --namespace "$NAMESPACE" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"
}

# Main
main()
{
    set -e
    export PATH=./bin:$PATH

    check_dependencies "docker" "kubectl" "kind" "kustomize" "ngrok" "tmux"
    [ "$SKIP_AWS" = "false" ] && check_dependencies "aws"
    [ "$SKIP_BITWARDEN" = "false" ] && check_dependencies "bw"

    # if not skipped and if locked, unlock bitwarden
    [ "$SKIP_BITWARDEN" = "false" ] && \
        [ "$( bw status | jq -r '.status' )" = "locked" ] && \
            BW_SESSION=$( bw unlock --raw )

    # cleanup
    rm -f "$KUBECONFIG"
    pkill "kubectl" || true
    pkill "ngrok" || true
    kind delete clusters "$CLUSTER_MAIN" "$CLUSTER_WORKER"

    # build dependencies
    # make primazactl

    # create AWS RDS if not existing
    [ "$SKIP_AWS" = "false" ] && create_aws_rds_prod && create_aws_rds_test

    # create multi-cluster environment
    create_main_cluster "$CLUSTER_MAIN" "$KUBECONFIG" "$CLUSTER_MAIN_CONTEXT"
    create_worker_cluster "$CLUSTER_WORKER" "$KUBECONFIG" "$CLUSTER_WORKER_CONTEXT"

    create_service_namespace "$SERVICE_NAMESPACE_PROD"
    create_service_namespace "$SERVICE_NAMESPACE_TEST"

    create_application_namespace \
        "$APPLICATION_NAMESPACE_PROD" \
        "$ARGOCD_PORT_PROD" \
        "$ARGOCD_WATCHED_REPO_FOLDER_PROD" \
        "prod" \
        32080 \
        32268

    create_application_namespace \
        "$APPLICATION_NAMESPACE_TEST" \
        "$ARGOCD_PORT_TEST" \
        "$ARGOCD_WATCHED_REPO_FOLDER_TEST" \
        "test" \
        32081 \
        32269

    wait_rollouts

    printf "tunneling with ngrok\n"
    tmux split-window -h "ngrok start --all --config $NGROK_LOCAL_CONFIG_PATH --config $NGROK_BASE_CONFIG_PATH"

    # Configure AWS to local cluster communication
    [ "$SKIP_AWS" = "false" ] && {
        port=8001
        kubectl proxy --disable-filter=true --port="$port" --kubeconfig "$KUBECONFIG" --context "$CLUSTER_MAIN_CONTEXT" &

        pub_url="null"
        until [ "$pub_url" != "null" ] && [ "$pub_url" != "" ]; do
            pub_url=$( curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[] | select(.name == "main") | .public_url' | sed 's/https:\/\///' )
            sleep 1
        done

        aws lambda update-function-configuration \
            --function-name service-catalog-discovery \
            --environment '{"Variables": {"K8_HOST": "'"$pub_url"'", "K8_TOKEN_SECRET": "arn:aws:secretsmanager:us-east-2:'"$( aws iam get-user --output text --query 'User.Arn' | cut -d':' -f5 )"':secret:filario/mvp-demo-test-yE9XFI", "PRIMAZA_TENANT": "primaza-mytenant"}}' \
            --no-cli-pager

        ps
    }

    worker_port=8002
    printf "Exposing Worker's Kubernetes API Server at localhost:%s\n" "$worker_port"
    kubectl proxy --disable-filter=true --port="$worker_port" --kubeconfig "$KUBECONFIG" --context "$CLUSTER_WORKER_CONTEXT" &> /dev/null &

    printf "Exposed services via ngrok\n"
    curl -s http://localhost:4040/api/tunnels | \
        jq '["NAME","PUBLIC URL"], ["------","------------------------------"], (.tunnels[] | [ .name, .public_url ]) | @tsv' -r

    bake_external_kubeconfig "$CLUSTER_MAIN"
    bake_external_kubeconfig "$CLUSTER_WORKER"

    setup_primaza_environment
}

main

