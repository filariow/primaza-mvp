#!/bin/env bash
#
# Cleanup Primaza MVP Demo's AWS

# Constants
## AWS Controllers for Kubernetes
AWS_RDS_DB_REGION="eu-west-3"

delete_aws_rds()
{
    [ "$(aws rds describe-db-instances \
            --filters 'Name=db-instance-id,Values="'"$1"'"' \
            --region "$AWS_RDS_DB_REGION" \
            --no-cli-pager | jq '.DBInstances | length')" != "0" ] && \
    {
        echo "deleting $1"
        aws rds delete-db-instance \
            --db-instance-identifier "$1" \
            --region "$AWS_RDS_DB_REGION" \
            --skip-final-snapshot \
            --no-cli-pager
    }
}

delete_sqs_queue()
{
    SQS_QUEUE_URL=$( aws sqs get-queue-url --queue-name "$1" --output text 2> /dev/null) && \
        echo "deleting queue $SQS_QUEUE_URL" && \
        aws sqs delete-queue --queue-url "$SQS_QUEUE_URL"
}

terminate_aws_servicecatalog_provisionedproduct()
{
    aws servicecatalog describe-provisioned-product \
        --name "$1" --no-cli-pager &> /dev/null && \
        echo "deleting Service Catalog Provisioned Product $1" && \
        aws servicecatalog terminate-provisioned-product \
            --provisioned-product-name "$1" \
            --no-cli-pager
}

main()
{
    delete_aws_rds "rds-pmz-demo-eph-catalog-prod"
    delete_aws_rds "rds-pmz-demo-eph-catalog-test"
    delete_sqs_queue "orders-prod"
    delete_sqs_queue "orders-test"
    terminate_aws_servicecatalog_provisionedproduct "primaza-demo-orders-prod"
    terminate_aws_servicecatalog_provisionedproduct "primaza-demo-orders-test"
}

main
