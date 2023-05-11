export AWS_RDS_DB_PASSWORD=$(bw generate)
export KUBECONFIG=/tmp/kc-mvp-primaza
if [ -z "$BW_SESSION" ]; then
    export BW_SESSION=$(bw unlock --raw)
else
    export BW_SESSION=$BW_SESSION
fi
