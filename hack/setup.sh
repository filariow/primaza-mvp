#!/bin/env bash
#
# Setup Primaza MVP

set -e

[ -z "$AWS_RDS_DB_PASSWORD" ] && echo "Please set the AWS_RDS_DB_PASSWORD Environment Variable" && exit 1

# Constants
## Infra
CLUSTER_MAIN="main"
CLUSTER_WORKER="worker"
CLUSTER_MAIN_CONTEXT="kind-$CLUSTER_MAIN"
CLUSTER_WORKER_CONTEXT="kind-$CLUSTER_WORKER"
APPLICATION_NAMESPACE="applications"
[ -z "$KUBECONFIG" ] && KUBECONFIG="/tmp/kc-mvp-primaza"

## Cert Manager
CERTMANAGER_VERSION="v1.11.1"

## AWS Controllers for Kubernetes
ACK_SYSTEM_NAMESPACE="services"
AWS_REGION="us-east-2"
AWS_RDS_DB_NAME="postgres"
AWS_RDS_DBINSTANCE_NAME="rds-primaza-demo-mvp-catalog"
AWS_RDS_DB_USERNAME="awsuser"
AWS_RDS_DB_SIZE="db.t3.small"
AWS_RDS_DB_ENGINE="postgres"

## ARGOCD
ARGOCD_NAMESPACE="$APPLICATION_NAMESPACE"
ARGOCD_WATCHED_REPO="https://github.com/filariow/primaza-mvp.git"
ARGOCD_WATCHED_REPO_FOLDER="config/claiming/outer-loop"
ARGOCD_VERSION="v2.7.3"

## NGROK
NGROK_BASE_CONFIG_PATH="$HOME/.config/ngrok/ngrok.yml"


[ -z "$SKIP_BITWARDEN" ] && SKIP_BITWARDEN="false"
[ -z "$SKIP_AWS" ] && SKIP_AWS="false"


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

configure_main_cluster()
(
    docker tag ghcr.io/primaza/primaza:latest ghcr.io/primaza/primaza:latestknown || true
    docker rmi ghcr.io/primaza/primaza:latest || true
    docker pull ghcr.io/primaza/primaza:latest
    kind load docker-image ghcr.io/primaza/primaza:latest --name "$CLUSTER_MAIN"
)

install_ack_controller()
{
    SERVICE=$1
    RELEASE_VERSION=$2

    aws ecr-public get-login-password --region us-east-1 | \
        helm registry login --username AWS --password-stdin public.ecr.aws

    helm install "ack-$SERVICE-controller" \
        "oci://public.ecr.aws/aws-controllers-k8s/$SERVICE-chart" \
        --namespace "$ACK_SYSTEM_NAMESPACE" \
        --create-namespace \
        --kubeconfig "$KUBECONFIG" \
        --kube-context "$CLUSTER_WORKER_CONTEXT" \
        --version="$RELEASE_VERSION" \
        --set=aws.region="$AWS_REGION" \
        --set=installScope=namespace

    kubectl set env "deployment/ack-$SERVICE-controller-$SERVICE-chart" \
        AWS_ACCESS_KEY_ID="$( aws configure get aws_access_key_id )" \
        AWS_SECRET_ACCESS_KEY="$( aws configure get aws_secret_access_key )" \
        --namespace "$ACK_SYSTEM_NAMESPACE" \
        --kubeconfig "$KUBECONFIG" \
        --context "$CLUSTER_WORKER_CONTEXT"
}

configure_worker_cluster()
{
    docker tag ghcr.io/primaza/primaza-agentapp:latest ghcr.io/primaza/primaza-agentapp:latestknown || true
    docker tag ghcr.io/primaza/primaza-agentsvc:latest ghcr.io/primaza/primaza-agentsvc:latestknown || true

    docker rmi ghcr.io/primaza/primaza-agentapp:latest || true
    docker rmi ghcr.io/primaza/primaza-agentsvc:latest || true

    docker pull ghcr.io/primaza/primaza-agentapp:latest
    docker pull ghcr.io/primaza/primaza-agentsvc:latest

    kind load docker-image ghcr.io/primaza/primaza-agentapp:latest --name "$CLUSTER_WORKER"
    kind load docker-image ghcr.io/primaza/primaza-agentsvc:latest --name "$CLUSTER_WORKER"

    [ "$SKIP_AWS" != "true" ] && {
        install_ack_controller \
          "sqs" \
          "$( curl -sL https://api.github.com/repos/aws-controllers-k8s/sqs-controller/releases/latest | grep '"tag_name":' | cut -d'"' -f4 | tr -d "v" )"
        # install_ack_controller \
        #   "iam" \
        #   "$(curl -sL https://api.github.com/repos/aws-controllers-k8s/iam-controller/releases/latest | grep '"tag_name":' | cut -d'"' -f4)"
    }

    build_and_load_demo_app_images
    install_and_configure_argocd
    install_and_configure_nginx_ingress
}

install_and_configure_argocd()
{
    # install ArgoCD
    kubectl create namespace applications \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG" \
        --dry-run=client --output=yaml | \
        kubectl apply -f - \
            --context "$CLUSTER_WORKER_CONTEXT" \
            --kubeconfig "$KUBECONFIG"

    # kubectl apply -k 'https://github.com/argoproj/argo-cd/manifests/crds?ref=stable' \
    kubectl apply -f "config/argocd/crds.yaml" \
        --namespace "$ARGOCD_NAMESPACE" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"

   kubectl apply -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/namespace-install.yaml" \
        --namespace "$ARGOCD_NAMESPACE" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"

    ARGO_SECRET=argocd-initial-admin-secret
    echo "waiting for secret $ARGO_SECRET to be created..."
    until kubectl get secrets \
        "$ARGO_SECRET" \
        --namespace "$ARGOCD_NAMESPACE" \
        --kubeconfig "$KUBECONFIG" \
        --context "$CLUSTER_WORKER_CONTEXT" &> /dev/null
    do
        sleep 5
    done
    echo "$ARGO_SECRET secret found..."

    until KUBECONFIG=$KUBECONFIG argocd login \
        --username admin \
        --password "$( argocd admin initial-password \
            --namespace "$ARGOCD_NAMESPACE" \
            --kube-context "$CLUSTER_WORKER_CONTEXT" \
            --kubeconfig "$KUBECONFIG" | head -n 1 )" \
        --port-forward --port-forward-namespace "$ARGOCD_NAMESPACE" --grpc-web \
        --insecure \
        --kube-context "$CLUSTER_WORKER_CONTEXT"; do
        sleep 2
    done

    until KUBECONFIG=$KUBECONFIG argocd cluster add --in-cluster --namespace "$ARGOCD_NAMESPACE" "$CLUSTER_WORKER_CONTEXT" --yes \
        --port-forward --port-forward-namespace applications --grpc-web --insecure \
        --kube-context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"; do
        sleep 2
    done


    until KUBECONFIG=$KUBECONFIG argocd app create demo-app-outer-loop \
        --repo "$ARGOCD_WATCHED_REPO" \
        --path "$ARGOCD_WATCHED_REPO_FOLDER" \
        --dest-server "https://kubernetes.default.svc" \
        --dest-namespace "$ARGOCD_NAMESPACE" \
        --kube-context "$CLUSTER_WORKER_CONTEXT" \
        --port-forward --port-forward-namespace "$ARGOCD_NAMESPACE" --grpc-web \
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
        --namespace "$ARGOCD_NAMESPACE" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"

    kubectl patch configmap argocd-cm \
        --patch-file <( cat << EOF
data:
  resource.customizations: |
    networking.k8s.io/Ingress:
        health.lua: |
          hs = {}
          hs.status = "Healthy"
          return hs
EOF
        ) \
        --namespace "$ARGOCD_NAMESPACE" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"
}

create_worker_cluster()
{
    kind create cluster --name "$1" --kubeconfig "$2" --config <( cat << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  # port forward 80 on the host to 80 on this node
  extraPortMappings:
  - containerPort: 32080
    hostPort: 80
    protocol: TCP
EOF
)

    ## install cert-manager
    install_cert_manager "$2" "$3"

    configure_worker_cluster
}

install_and_configure_nginx_ingress()
{
    helm upgrade --install "ingress-nginx" "ingress-nginx" \
        --repo "https://kubernetes.github.io/ingress-nginx" \
        --namespace "$APPLICATION_NAMESPACE" --create-namespace \
        --kubeconfig "$KUBECONFIG"

    kubectl patch services ingress-nginx-controller --patch \
        '{ "spec": { "ports": [ { "appProtocol": "http", "name": "http", "nodePort": 32080, "port": 80, "protocol": "TCP", "targetPort": 80}, { "appProtocol": "https", "name": "https", "nodePort": 32268, "port": 443, "protocol": "TCP", "targetPort": 443 } ] } }' \
        --namespace "$APPLICATION_NAMESPACE" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG"
}

create_main_cluster()
{
    kind create cluster --name "$1" --kubeconfig "$2"

    ## install cert-manager
    install_cert_manager "$2" "$3"

    configure_main_cluster
}

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

create_aws_rds()
{
    set -e

    if [ "$(aws rds describe-db-instances \
            --filters 'Name=db-instance-id,Values="'"$AWS_RDS_DBINSTANCE_NAME"'"' \
            --no-cli-pager | jq '.DBInstances | length')" = "0" ]; then
        aws rds create-db-instance \
            --db-instance-identifier "$AWS_RDS_DBINSTANCE_NAME" \
            --db-instance-class "$AWS_RDS_DB_SIZE" \
            --db-name "$AWS_RDS_DB_NAME" \
            --engine "$AWS_RDS_DB_ENGINE" \
            --master-user-password "$AWS_RDS_DB_PASSWORD" \
            --master-username "$AWS_RDS_DB_USERNAME" \
            --allocated-storage 20 \
            --publicly-accessible \
            --no-cli-pager
    else
        aws rds modify-db-instance \
            --db-instance-identifier "$AWS_RDS_DBINSTANCE_NAME" \
            --master-user-password "$AWS_RDS_DB_PASSWORD" \
            --no-cli-pager
    fi

    group_id=$( aws rds describe-db-instances \
        --filters 'Name=db-instance-id,Values="'"$AWS_RDS_DBINSTANCE_NAME"'"' \
        --no-cli-pager | jq -r '.DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' )
    exist_inbound_rule=$( aws ec2 describe-security-group-rules \
        --filter 'Name="group-id",Values="'"$group_id"'"' | \
        jq '[.SecurityGroupRules[] | select(.ToPort == 5432 and .CidrIpv4 == "0.0.0.0/0")] | length' )

    if [ "$exist_inbound_rule" == "0" ]
    then
        aws ec2 authorize-security-group-ingress \
            --group-id "$group_id" \
            --protocol "tcp" \
            --port "5432" \
            --cidr "0.0.0.0/0" \
            --no-cli-pager
    fi
}

main()
{
    set -e
    export PATH=./bin:$PATH

    check_dependencies "docker" "kubectl" "kind" "kustomize" "ngrok"
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
    make primazactl

    # create AWS RDS if not existing
    [ "$SKIP_AWS" = "false" ] && create_aws_rds

    # create multi-cluster environment
    create_main_cluster "$CLUSTER_MAIN" "$KUBECONFIG" "$CLUSTER_MAIN_CONTEXT"
    create_worker_cluster "$CLUSTER_WORKER" "$KUBECONFIG" "$CLUSTER_WORKER_CONTEXT"
    wait_rollouts

    printf "tunneling with ngrok"
    ngrok start --all --config hack/ngrok.yml --config "$NGROK_BASE_CONFIG_PATH" &> /dev/null &

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

    argocd_password=$(argocd admin initial-password --namespace "$ARGOCD_NAMESPACE" \
        --kube-context "$CLUSTER_WORKER_CONTEXT" \
        --kubeconfig "$KUBECONFIG" | head -n 1)

    [ "$SKIP_BITWARDEN" = "false" ] && {
        argocd_uri=$( curl -s http://localhost:4040/api/tunnels | jq '.tunnels[] | select(.name == "worker") | .public_url' -r )
        argocd_sec=$( bw get item argocd --session "$BW_SESSION" )
        argocd_sec_id=$( echo "$argocd_sec" | jq -r '.id' )
        [ -n "$argocd_sec_id" ] && \
                echo "$argocd_sec" | \
                    jq --arg v "$argocd_password" '.login.password=$v' | \
                    jq --arg v "$argocd_uri" '.login.uris[1].uri=$v' | \
                    bw encode | \
                    bw edit item "$argocd_sec_id" --session "$BW_SESSION"
    }

    # Expose ArgoCD
    argocd_port=8080
    printf "\nArgoCD Web UI is published at https://localhost:%s\nadmin account password: %s\n" "$argocd_port" "$argocd_password"
    kubectl port-forward "services/argocd-server" "$argocd_port:443" \
        --context "$CLUSTER_WORKER_CONTEXT" \
        --namespace "$ARGOCD_NAMESPACE" \
        --kubeconfig "$KUBECONFIG" &> /dev/null &

    worker_port=8002
    printf "Exposing Worker's Kubernetes API Server at localhost:%s" "$worker_port"
    kubectl proxy --disable-filter=true --port="$worker_port" --kubeconfig "$KUBECONFIG" --context "$CLUSTER_MAIN_CONTEXT" &> /dev/null &

    printf "Exposed services"
    curl -s http://localhost:4040/api/tunnels | \
        jq '["NAME","PUBLIC URL"], ["------","------------------------------"], (.tunnels[] | [ .name, .public_url ]) | @tsv' -r
}

main

