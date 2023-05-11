package discovery

import (
	"fmt"
	"os"

	demo "github.com/saschagrunert/demo"
)

const (
	rdsName        = ""
	rdsPasswordEnv = "AWS_RDS_DB_PASSWORD"
)

func manualRegistrationRDSRunSetup() error {
	if _, ok := os.LookupEnv(rdsPasswordEnv); !ok {
		return fmt.Errorf("Missing required Environment Variable '%s'", rdsPasswordEnv)
	}
	return nil
}

func ManualRegistrationRDSRun() *demo.Run {
	r := demo.NewRun("Manually registering a Registered Service")
	r.Setup(manualRegistrationRDSRunSetup)

	r.Step(
		demo.S("We already have a AWS RDS Postgres DBInstance"),
		demo.S("aws rds describe-db-instances ",
			`--filters 'Name=db-instance-id,Values="rds-primaza-demo-mvp-catalog"'`,
			"--query 'DBInstances[0].{Identifier: DBInstanceIdentifier, Class: DBInstanceClass, Engine: Engine, Status: DBInstanceStatus, MasterUsername: MasterUsername, Endpoint: Endpoint, DBInstanceArn: DBInstanceArn}'",
			"--no-cli-pager "))

	r.Step(
		demo.S("Create a RegisteredService for the DBInstance"),
		demo.S(`db=$(aws rds describe-db-instances \
	--filters 'Name=db-instance-id,Values="rds-primaza-demo-mvp-catalog"' \
	--query 'DBInstances[0].{MasterUsername: MasterUsername, Endpoint: Endpoint}' \
	--no-cli-pager)

cat << EOF | kubectl apply -f - -n primaza-mytenant --context kind-main
apiVersion: v1
kind: Secret
metadata:
  name: rds-credentials
  namespace: primaza-mytenant
stringData:
  username: $( echo "$db" | jq -r '.MasterUsername' )
  password: $( echo "$AWS_RDS_DB_PASSWORD" )
---
apiVersion: primaza.io/v1alpha1
kind: RegisteredService
metadata:
  name: rds
  namespace: primaza-mytenant
spec:
  constraints:
    environments:
    - demo
  serviceClassIdentity:
  - name: type
    value: rds
  - name: provider
    value: aws
  - name: engine
    value: postgres
  serviceEndpointDefinition:
  - name: database
    value: postgres
  - name: host
    value: "$( echo "$db" | jq -r '.Endpoint.Address' )"
  - name: port
    value: "$( echo "$db" | jq -r '.Endpoint.Port' )"
  - name: password
    valueFromSecret:
      name: rds-credentials
      key: password
  - name: username
    valueFromSecret:
      name: rds-credentials
      key: username
EOF
`))

	return r
}
