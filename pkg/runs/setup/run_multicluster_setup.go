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

	r.Step(
		demo.S("Join a worker cluster to Tenant 'primaza-mytenant'"),
		demo.S("./bin/primazactl join cluster ",
			"--version latest",
			"--tenant primaza-mytenant",
			"--cluster-environment worker",
			"--environment demo",
			"--context kind-worker",
			"--tenant-context kind-main",
		),
	)

	r.Step(
		demo.S("Create an Application Namespace on joined cluster 'worker'"),
		demo.S("./bin/primazactl create application-namespace applications",
			"--version latest",
			"--tenant primaza-mytenant",
			"--cluster-environment worker",
			"--context kind-worker",
			"--tenant-context kind-main",
		),
	)

	r.Step(
		demo.S("Create a Service Namespace on joined cluster 'worker'"),
		demo.S("./bin/primazactl create service-namespace services",
			"--version latest",
			"--tenant primaza-mytenant",
			"--cluster-environment worker",
			"--context kind-worker",
			"--tenant-context kind-main",
		),
	)

	return r
}
