AWS_RDS_DB_PASSWORD_FILE=/tmp/primaza-mv-demo-aws-rds-password
[ ! -s "$AWS_RDS_DB_PASSWORD_FILES" ] && bw generate > "$AWS_RDS_DB_PASSWORD_FILE"

export AWS_RDS_DB_PASSWORD=$(cat "$AWS_RDS_DB_PASSWORD_FILE")
export KUBECONFIG=/tmp/kc-mvp-primaza

if [ -z "$SKIP_BITWARDEN" ] || [ "$SKIP_BITWARDEN" = "false" ]; then
    if command -v bw > /dev/null && [ -z "$BW_SESSION" ]; then
        export BW_SESSION=$(bw unlock --raw)
    else
        export BW_SESSION=$BW_SESSION
    fi
fi
