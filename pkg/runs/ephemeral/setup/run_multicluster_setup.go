package setup

import (
	demo "github.com/saschagrunert/demo"
)

func MultiClusterEnvDemoRun() *demo.Run {
	r := demo.NewRun("Create Multi-Cluster environment with Kind")

	r.Step(
		demo.S("Create a Primaza Tenant on cluster 'main'"),
		demo.S("./bin/primazactl create tenant primaza-mytenant --version latest --context kind-main"),
	)

	// Prod
	r.Step(
		demo.S("Join a worker cluster to Tenant 'primaza-mytenant' for Environment 'prod'"),
		demo.S("./bin/primazactl join cluster ",
			"--version latest",
			"--tenant primaza-mytenant",
			"--cluster-environment worker-prod",
			"--environment prod",
			"--context kind-worker",
			"--tenant-context kind-main",
		),
	)

	r.Step(
		demo.S("Create the  Application Namespace 'applications-prod' on joined cluster 'worker-prod'"),
		demo.S("./bin/primazactl create application-namespace applications-prod",
			"--version latest",
			"--tenant primaza-mytenant",
			"--cluster-environment worker-prod",
			"--context kind-worker",
			"--tenant-context kind-main",
		),
	)

	r.Step(
		demo.S("Create a Service Namespace 'services-prod' on joined cluster 'worker-prod'"),
		demo.S("./bin/primazactl create service-namespace services-prod",
			"--version latest",
			"--tenant primaza-mytenant",
			"--cluster-environment worker-prod",
			"--context kind-worker",
			"--tenant-context kind-main",
		),
	)

	// Test Services
	r.Step(
		demo.S("Join a worker cluster to Tenant 'primaza-mytenant' for Environment 'test-services'"),
		demo.S("./bin/primazactl join cluster ",
			"--version latest",
			"--tenant primaza-mytenant",
			"--cluster-environment worker-test-services",
			"--environment test-services",
			"--context kind-worker",
			"--tenant-context kind-main",
		),
	)

	r.Step(
		demo.S("Create a Service Namespace 'services-test' on joined cluster 'worker-test-services'"),
		demo.S("./bin/primazactl create service-namespace services-test",
			"--version latest",
			"--tenant primaza-mytenant",
			"--cluster-environment worker-test-services",
			"--context kind-worker",
			"--tenant-context kind-main",
		),
	)

	return r
}
