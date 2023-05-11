package setup

import (
	demo "github.com/saschagrunert/demo"
)

func MultiClusterEnvDemoLocalRun() *demo.Run {
	r := demo.NewRun("Create Multi-Cluster environment with Kind from local manifests")

	r.Step(
		demo.S("Create a Primaza Tenant on cluster 'main'"),
		demo.S("./bin/primazactl create tenant primaza-mytenant",
			"--version latest",
			"--context kind-main",
			"--config ./config/primaza/primaza_main_config_latest.yaml",
		),
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
			"--config ./config/primaza/primaza_worker_config_latest.yaml",
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
			"--config ./config/primaza/application_agent_config_latest.yaml",
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
			"--config ./config/primaza/service_agent_config_latest.yaml",
		),
	)

	return r
}
