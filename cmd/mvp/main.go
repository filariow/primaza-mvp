package main

import (
	"fmt"
	"os"

	"github.com/filariow/primaza-mvp/pkg/runs/discovery"
	"github.com/filariow/primaza-mvp/pkg/runs/setup"
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
	d.Add(discovery.ManualRegistrationRDSRun(),
		"manual-registration-rds",
		"Manually registering an RDS service")
	d.Add(discovery.DiscoverySQSRun(),
		"discovery-sqs",
		"Discover an SQS Queue")
	d.Add(
		discovery.AWSServiceCatalogRun(),
		"aws-service-catalog",
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
