package discovery

import (
	"fmt"
	"os/exec"
	"time"

	demo "github.com/saschagrunert/demo"
)

const (
	serviceCatalogProductName = "primaza-demo-orders"
	lambdaName                = "pmz-demo-orders"
)

func AWSServiceCatalogRunSetup() error {
	cmdTerminate := fmt.Sprintf(
		`aws servicecatalog terminate-provisioned-product --provisioned-product-name "%s" --no-cli-pager`,
		serviceCatalogProductName)
	if err := exec.Command("bash", "-c", cmdTerminate).Run(); err != nil {
		// TODO: it may mean that the provisioned-product does not exist,
		// but also network problems or other generic errors.
		// Checking with `describe-provisioned-product` would be safer
		return nil
	}

	fmt.Printf("terminating service catalog '%s'\n", serviceCatalogProductName)
	cmdDescribe := fmt.Sprintf(
		`aws servicecatalog describe-provisioned-product --name %s --no-cli-pager`,
		serviceCatalogProductName)
	for {
		fe := exec.Command("bash", "-c", cmdDescribe).Run()
		if fe != nil {
			return nil
		}

		time.Sleep(2 * time.Second)
	}
}

func AWSServiceCatalogRun() *demo.Run {
	r := demo.NewRun("3rd-party integration with AWS Service Catalog")
	r.Setup(AWSServiceCatalogRunSetup)

	r.Step(
		demo.S("Create the Service Account and Secret for integration"),
		demo.S(
			"kubectl create serviceaccount aws-servicecatalog-integration -n primaza-mytenant --context kind-main --dry-run=client -o yaml | kubectl apply -f - --context kind-main 2> /dev/null &&",
			`cat << EOF | kubectl apply -f - -n primaza-mytenant --context kind-main &&
apiVersion: v1
kind: Secret
metadata:
  name: aws-servicecatalog-integration
  namespace: primaza-mytenant
  annotations:
    kubernetes.io/service-account.name: aws-servicecatalog-integration
type: kubernetes.io/service-account-token
EOF
`,
			"kubectl create rolebinding",
			"--serviceaccount=primaza-mytenant:aws-servicecatalog-integration",
			"--role primaza-reporter primaza:reporter-aws-servicecatalog-integration",
			"--dry-run=client -o yaml | kubectl apply -f - --context kind-main 2> /dev/null &&",
			`until`,
			`"$(kubectl get secrets -n primaza-mytenant --context kind-main -o json aws-servicecatalog-integration | jq '.data | has("token")')" = "true";`,
			`do sleep 2; echo "access token still not ready..."; done; echo "access token generated"`,
		))

	r.Step(
		demo.S("Fetch the Access Token and store it in AWS Secret Manager"),
		demo.S("aws secretsmanager put-secret-value",
			"--secret-id filario/mvp-demo-test",
			`--secret-string '{"K8_TOKEN": "'"$(kubectl get secret -o json -n primaza-mytenant aws-servicecatalog-integration --context kind-main | jq -r '.data.token | @base64d')"'"}'`,
			"--no-cli-pager"))

	r.Step(
		demo.S("Create a Service Catalog's Provisioned Product"),
		demo.S("aws servicecatalog provision-product",
			"--product-name PrimazaDynamoDB",
			fmt.Sprintf("--provisioned-product-name %s", serviceCatalogProductName),
			"--provisioning-artifact-name primaza-mvp-demo",
			"--provisioning-parameters",
			fmt.Sprintf("Key=LambdaName,Value=%s", lambdaName),
			`Key=QueueURL,Value=$(kubectl get queues.sqs.services.k8s.aws sqs-orders -o jsonpath='{.status.queueURL}' --context kind-worker --namespace services )`,
			"--no-cli-pager"))

	r.Step(
		demo.S("Monitor the Service Catalog deployment"),
		demo.S(
			`echo "https://us-east-2.console.aws.amazon.com/servicecatalog/home?region=us-east-2#provisioned-products" &&`,
			fmt.Sprintf(`until [ "$(aws servicecatalog describe-provisioned-product --name %s --query 'ProvisionedProductDetail.Status' --no-cli-pager)" != "AVAILABLE" ];`, serviceCatalogProductName),
			`do sleep 2; done`,
		))

	r.Step(
		demo.S("A Registered Services and its Secret are created"),
		demo.S(
			fmt.Sprintf(
				`uid=$( aws servicecatalog describe-provisioned-product --name %s --no-cli-pager --query 'ProvisionedProductDetail.Arn' | cut -d':' -f5 | tr -d '"' ) &&`,
				serviceCatalogProductName),
			fmt.Sprintf(
				`id=$( aws servicecatalog describe-provisioned-product --name %s --no-cli-pager --query 'ProvisionedProductDetail.Id' | cut -d':' -f5 | tr -d '"' ) &&`,
				serviceCatalogProductName),
			`name="sc-$uid-$id" &&`,
			`until [[ "$(kubectl get registeredservices -n primaza-mytenant --context kind-main -o json "$name" 2> /dev/null | jq -r '.status.state' )" = "Available" ]]; do sleep 1; done &&`,
			`until kubectl get secrets -n primaza-mytenant --context kind-main -o json "$name" &> /dev/null; do sleep 1; done &&`,
			`kubectl get registeredservices -n primaza-mytenant --context kind-main "$name" -o yaml &&`,
			`echo "---" && `,
			`kubectl get secrets -n primaza-mytenant --context kind-main "$name" -o yaml | sed 's/access_key_id: .*$/access_key_id: xxxxxx/g;s/secret_access_key: .*$/secret_access_key: xxxxxx/g'`))

	return r
}
