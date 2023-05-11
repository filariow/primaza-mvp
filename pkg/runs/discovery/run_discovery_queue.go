package discovery

import (
	demo "github.com/saschagrunert/demo"
)

func DiscoverySQSRun() *demo.Run {
	r := demo.NewRun("Discovering an AWS SQS Queue managed by ACK")

	r.Step(
		demo.S("Create a service in service namespace 'services'"),
		demo.S("cat ./config/discovery/services/queue/queue.yaml &&",
			"kubectl apply", "-f ./config/discovery/services/queue/queue.yaml", "--namespace services", "--context kind-worker"))

	r.Step(
		demo.S("Grant rights for discovering SQS Queue in service namespace to Primaza's Service Agent"),
		demo.S("cat ./config/discovery/services/queue/queue_read_role.yaml &&",
			"kubectl apply", "-f ./config/discovery/services/queue/queue_read_role.yaml", "--namespace services", "--context kind-worker"))

	r.Step(
		demo.S("Create a Secret with Credentials to access the SQS Queue"),
		demo.S(`current_user=$(aws iam get-user --query 'User.UserName' --output text)
aws iam attach-user-policy --user-name "$current_user" --policy-arn "arn:aws:iam::aws:policy/AmazonSQSFullAccess"

cat << EOF | kubectl apply -f - -n services --context kind-worker
apiVersion: v1
kind: Secret
metadata:
  name: sqs-orders
stringData:
  AWS_ACCESS_KEY_ID: $( aws configure get aws_access_key_id )
  AWS_SECRET_ACCESS_KEY: $( aws configure get aws_secret_access_key )
EOF
`))

	r.Step(
		demo.S("Create the Service Class for discovering Queue services"),
		demo.S("cat ./config/discovery/services/queue/service_class.yaml &&",
			"kubectl apply", "-f ./config/discovery/services/queue/service_class.yaml", "--namespace primaza-mytenant", "--context kind-main"))

	r.Step(
		demo.S("A Registered Service and a Secret are created in Primaza"),
		demo.S("until",
			"kubectl get registeredservices -n primaza-mytenant --context kind-main -o yaml sqs-orders 2> /dev/null;",
			"do sleep 2; done;",
			`    echo "---" &&`,
			"    kubectl get secrets sqs-orders-descriptor",
			"        --namespace primaza-mytenant",
			"        --context kind-main",
			"        --output yaml 2> /dev/null |",
			"            sed 's/access_key_id: .*$/access_key_id: xxxxxx/g;s/secret_access_key: .*$/secret_access_key: xxxxxx/g'",
		))

	return r
}
