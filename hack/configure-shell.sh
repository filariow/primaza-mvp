#!/bin/bash

AWS_RDS_DB_PASSWORD_FILE=/tmp/primaza-mv-demo-aws-rds-password
[ -s "$AWS_RDS_DB_PASSWORD_FILE" ] || tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 > "$AWS_RDS_DB_PASSWORD_FILE"

export AWS_RDS_DB_PASSWORD=$(cat "$AWS_RDS_DB_PASSWORD_FILE")
export KUBECONFIG=/tmp/kc-mvp-primaza

if [ -z "$SKIP_BITWARDEN" ] || [ "$SKIP_BITWARDEN" = "false" ]; then
    if command -v bw > /dev/null && [ -z "$BW_SESSION" ]; then
        export BW_SESSION=$(bw unlock --raw)
    else
        [ "$( bw status | jq -r '.status' )" = "locked" ] && BW_SESSION=$( bw unlock --raw )
        export BW_SESSION=$BW_SESSION
    fi
fi

print_primaza_urls()
{
    curl -s http://localhost:4040/api/tunnels | \
        jq '["NAME","PUBLIC URL"], ["------","------------------------------"], (.tunnels[] | [ .name, .public_url ]) | @tsv' -r
}
