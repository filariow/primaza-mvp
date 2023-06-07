#!/bin/env bash
#
# Cleanup Primaza MVP Demo's AWS

# Constants
## AWS Controllers for Kubernetes
ACK_SYSTEM_NAMESPACE="services"
AWS_RDS_DBINSTANCE_NAME="rds-primaza-demo-mvp-catalog"
AWS_SC_PROVPRODUCT_NAME="primaza-demo-orders"
AWS_RDS_DB_REGION="eu-west-3"


delete_aws_rds()
{
    [ "$(aws rds describe-db-instances \
            --filters 'Name=db-instance-id,Values="'"$AWS_RDS_DBINSTANCE_NAME"'"' \
            --region "$AWS_RDS_DB_REGION" \
            --no-cli-pager | jq '.DBInstances | length')" != "0" ] && \
    {
        echo "deleting $AWS_RDS_DBINSTANCE_NAME"
        aws rds delete-db-instance \
            --db-instance-identifier "$AWS_RDS_DBINSTANCE_NAME" \
            --region "$AWS_RDS_DB_REGION" \
            --skip-final-snapshot \
            --no-cli-pager
    }
}

delete_sqs_queue()
{
    SQS_QUEUE_URL=$( aws sqs get-queue-url --queue-name orders --output text 2> /dev/null) && \
        echo "deleting queue $SQS_QUEUE_URL" && \
        aws sqs delete-queue --queue-url "$SQS_QUEUE_URL"
}

terminate_aws_servicecatalog_provisionedproduct()
{
    aws servicecatalog describe-provisioned-product \
        --name "$AWS_SC_PROVPRODUCT_NAME" --no-cli-pager &> /dev/null && \
        echo "deleting Service Catalog Provisioned Product $AWS_SC_PROVPRODUCT_NAME" && \
        aws servicecatalog terminate-provisioned-product \
            --provisioned-product-name "$AWS_SC_PROVPRODUCT_NAME" \
            --no-cli-pager
}

main()
{
    delete_aws_rds
    delete_sqs_queue
    terminate_aws_servicecatalog_provisionedproduct
}

main
