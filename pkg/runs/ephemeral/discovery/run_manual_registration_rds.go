package discovery

import (
	"fmt"
	"os"
	"strings"

	demo "github.com/saschagrunert/demo"
)

const (
	rdsName   = ""
	rdsRegion = "eu-west-3"
)

func manualRegistrationRDSRunSetup(env string) func() error {
	return func() error {
		rdsPasswordEnv := fmt.Sprintf("AWS_RDS_%s_DB_PASSWORD", strings.ToUpper(env))
		if _, ok := os.LookupEnv(rdsPasswordEnv); !ok {
			return fmt.Errorf("Missing required Environment Variable '%s'", rdsPasswordEnv)
		}
		return nil
	}
}

func ManualRegistrationRDSRun(env string) *demo.Run {
	dbIdentifier := fmt.Sprintf("rds-pmz-demo-eph-catalog-%s", env)
	r := demo.NewRun("Manually registering a Registered Service")
	r.Setup(manualRegistrationRDSRunSetup(env))

	r.Step(
		demo.S("We already have a AWS RDS Postgres DBInstance"),
		demo.S("aws rds describe-db-instances ",
			fmt.Sprintf(`--filters 'Name=db-instance-id,Values="%s"'`, dbIdentifier),
			fmt.Sprintf("--region '%s'", rdsRegion),
			"--query 'DBInstances[0].{Identifier: DBInstanceIdentifier, Class: DBInstanceClass, Engine: Engine, Status: DBInstanceStatus, MasterUsername: MasterUsername, Endpoint: Endpoint, DBInstanceArn: DBInstanceArn}'",
			"--no-cli-pager "))

	envConstraint := env
	if env != "prod" {
		envConstraint = "!prod"
	}

	r.Step(
		demo.S("Create a RegisteredService for the DBInstance"),
		demo.S(fmt.Sprintf(`db=$(aws rds describe-db-instances \
	--filters 'Name=db-instance-id,Values="%s"' \
	--region "%s" \
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
  password: $( echo "$AWS_RDS_%s_DB_PASSWORD" )
---
apiVersion: primaza.io/v1alpha1
kind: RegisteredService
metadata:
  name: rds-%s
  namespace: primaza-mytenant
spec:
  constraints:
    environments:
    - "%s"
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
`, dbIdentifier, rdsRegion, strings.ToUpper(env), env, envConstraint)))

	return r
}
