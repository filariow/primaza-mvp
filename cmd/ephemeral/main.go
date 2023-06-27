package main

import (
	"fmt"
	"os"

	"github.com/filariow/primaza-mvp/pkg/runs/ephemeral/discovery"
	"github.com/filariow/primaza-mvp/pkg/runs/ephemeral/setup"
	demo "github.com/saschagrunert/demo"
	"github.com/urfave/cli/v2"
)

func main() {
	d := demo.New()
	d.Name = "mvp-demo"
	d.Usage = "Demonstrate how Primaza work"
	d.HideVersion = true

	d.Add(
		setup.MultiClusterEnvDemoRun(),
		"env-setup",
		"Multi cluster environment setup")

	// PROD
	d.Add(discovery.ManualRegistrationRDSRun("prod"),
		"manual-registration-rds-prod",
		"Manually registering an RDS service in Prod")
	d.Add(discovery.DiscoverySQSRun("prod"),
		"discovery-sqs-prod",
		"Discover an SQS Queue in Prod")
	d.Add(
		discovery.AWSServiceCatalogRun("prod"),
		"aws-service-catalog-prod",
		"Setup 3rd-party integration with AWS")

	// TEST
	d.Add(discovery.ManualRegistrationRDSRun("test"),
		"manual-registration-rds-test",
		"Manually registering an RDS service in Test")
	d.Add(discovery.DiscoverySQSRun("test"),
		"discovery-sqs-test",
		"Discover an SQS Queue in Test")
	d.Add(
		discovery.AWSServiceCatalogRun("test"),
		"aws-service-catalog-test",
		"Setup 3rd-party integration with AWS")

	d.Add(
		setup.MultiClusterEnvDemoLocalRun(),
		"env-setup-local",
		"Multi cluster environment setup from local files")

	d.Setup(checkKubeconfigEnv)

	d.Run()
}

func checkKubeconfigEnv(*cli.Context) error {
	if _, ok := os.LookupEnv("KUBECONFIG"); !ok {
		return fmt.Errorf("environment variable KUBECONFIG is not set")
	}
	return nil
}
