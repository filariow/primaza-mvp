package setup

import (
	demo "github.com/saschagrunert/demo"
)

func EphemeralCreateRun() *demo.Run {
	r := demo.NewRun("Create an Ephemeral environment")

	// Test
	r.Step(
		demo.S("Join a worker cluster to Tenant 'primaza-mytenant' for Environment 'test'"),
		demo.S("./bin/primazactl join cluster ",
			"--version latest",
			"--tenant primaza-mytenant",
			"--cluster-environment worker-test",
			"--environment test",
			"--context kind-worker",
			"--tenant-context kind-main",
		),
	)

	r.Step(
		demo.S("Create an Application Namespace 'applications-test' on joined cluster 'worker-test'"),
		demo.S("./bin/primazactl create application-namespace applications-test",
			"--version latest",
			"--tenant primaza-mytenant",
			"--cluster-environment worker-test",
			"--context kind-worker",
			"--tenant-context kind-main",
		),
	)

	return r
}
