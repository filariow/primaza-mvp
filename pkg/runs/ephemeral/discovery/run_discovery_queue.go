package discovery

import (
	"fmt"

	demo "github.com/saschagrunert/demo"
)

func DiscoverySQSRun(env string) *demo.Run {
	r := demo.NewRun("Discovering an AWS SQS Queue managed by ACK")

	namespace := fmt.Sprintf("services-%s", env)

	r.Step(
		demo.S(
			fmt.Sprintf("Create a service in service namespace 'services-%s'", env)),
		demo.S(
			fmt.Sprintf("cat %s/%s/discovery/services/queue/queue.yaml &&", configBasePath, env),
			"kubectl apply",
			fmt.Sprintf("-f %s/%s/discovery/services/queue/queue.yaml", configBasePath, env),
			fmt.Sprintf("--namespace %s", namespace),
			"--context kind-worker"))

	r.Step(
		demo.S("Grant rights for discovering SQS Queue in service namespace to Primaza's Service Agent"),
		demo.S(
			fmt.Sprintf("cat %s/%s/discovery/services/queue/queue_read_role.yaml &&", configBasePath, env),
			"kubectl apply",
			fmt.Sprintf("-f %s/%s/discovery/services/queue/queue_read_role.yaml", configBasePath, env),
			fmt.Sprintf("--namespace %s", namespace),
			"--context kind-worker"))

	r.Step(
		demo.S("Create a Secret with Credentials to access the SQS Queue"),
		demo.S(fmt.Sprintf(`current_user=$(aws iam get-user --query 'User.UserName' --output text)
aws iam attach-user-policy --user-name "$current_user" --policy-arn "arn:aws:iam::aws:policy/AmazonSQSFullAccess"

cat << EOF | kubectl apply -f - -n "%s" --context kind-worker
apiVersion: v1
kind: Secret
metadata:
  name: sqs-orders-%s
stringData:
  AWS_ACCESS_KEY_ID: $( aws configure get aws_access_key_id )
  AWS_SECRET_ACCESS_KEY: $( aws configure get aws_secret_access_key )
EOF
`, namespace, env)))

	r.Step(
		demo.S("Create the Service Class for discovering Queue services"),
		demo.S(
			fmt.Sprintf("cat %s/%s/discovery/services/queue/service_class.yaml &&", configBasePath, env),
			"kubectl apply",
			fmt.Sprintf("-f %s/%s/discovery/services/queue/service_class.yaml", configBasePath, env),
			"--namespace primaza-mytenant",
			"--context kind-main"))

	r.Step(
		demo.S("A Registered Service and a Secret are created in Primaza"),
		demo.S("until",
			fmt.Sprintf("kubectl get registeredservices -n primaza-mytenant --context kind-main -o yaml sqs-orders-%s 2> /dev/null;", env),
			"do sleep 2; done;",
			`    echo "---" &&`,
			fmt.Sprintf("    kubectl get secrets sqs-orders-%s-descriptor", env),
			"        --namespace primaza-mytenant",
			"        --context kind-main",
			"        --output yaml 2> /dev/null |",
			"            sed 's/access_key_id: .*$/access_key_id: xxxxxx/g;s/secret_access_key: .*$/secret_access_key: xxxxxx/g'",
		))

	return r
}
