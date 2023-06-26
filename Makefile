SKIP_BITWARDEN ?= false
SKIP_AWS ?= false

.PHONY: all
all: setup run-all-demos
	@:

#@ Common

binfolder:
	@mkdir -p ./bin

.PHONY: local-manifests
local-manifests:
	mkdir -p config/primaza
	cd config/primaza && \
		curl -sL \
			-O https://github.com/primaza/primazactl/releases/download/latest/application_agent_config_latest.yaml \
			-O https://github.com/primaza/primazactl/releases/download/latest/service_agent_config_latest.yaml \
			-O https://github.com/primaza/primazactl/releases/download/latest/primaza_main_config_latest.yaml \
			-O https://github.com/primaza/primazactl/releases/download/latest/primaza_worker_config_latest.yaml

.PHONY: primazactl
primazactl: binfolder
	@cd bin && \
		curl -sL -O https://github.com/primaza/primazactl/releases/download/latest/primazactl && \
		chmod +x primazactl

.PHONY: print-tunnels
print-tunnels:
	@curl -s http://localhost:4040/api/tunnels | \
        jq '["NAME","PUBLIC URL"], ["------","------------------------------"], (.tunnels[] | [ .name, .public_url ]) | @tsv' -r

#@ MVP Demo

.PHONY: run-all-demos
run-all-demos: build
	@./bin/main -0 -a -t 0 -i
	@./bin/main -1 -a -t 0 -i
	@./bin/main -2 -a -t 0 -i
	@./bin/main -3 -a -t 0 -i
	@curl -s http://localhost:4040/api/tunnels | \
        jq '["NAME","PUBLIC URL"], ["------","------------------------------"], (.tunnels[] | [ .name, .public_url ]) | @tsv' -r

.PHONY: build
build: binfolder
	@go build -o ./bin/main cmd/mvp/main.go

.PHONY: run-env-setup
run-env-setup: build
	@./bin/main --env-setup -a -t 5s -i

.PHONY: run-manual-registration
run-manual-registration: build
	@./bin/main --manual-registration-rds

.PHONY: run-discovery-sqs
run-discovery-sqs: build
	@./bin/main --discovery-sqs

.PHONY: run-aws-service-catalog
run-aws-service-catalog: build
	@./bin/main --aws-service-catalog -i

.PHONY: setup
setup: build primazactl
	SKIP_BITWARDEN=$(SKIP_BITWARDEN) SKIP_AWS=$(SKIP_AWS) ./hack/setup.sh

.PHONY: clean
clean:
	./hack/cleanup_aws.sh
	kind delete clusters main worker

.PHONY: book-mvp
book-mvp:
	@(cd docs/mvp && mdbook build)

#@ Ephemeral

.PHONY: ephemeral-build
ephemeral-build: binfolder
	@go build -o ./bin/main-ephemeral ./cmd/ephemeral/main.go

.PHONY: ephemeral-run-setup-env
ephemeral-run-setup-env: ephemeral-build
	@./bin/main-ephemeral --env-setup -a -t 0 -i

.PHONY: ephemeral-run-services-demos
ephemeral-run-services-demos: ephemeral-build
	@./bin/main-ephemeral --manual-registration-rds-prod -a -t 0 -i
	@./bin/main-ephemeral --discovery-sqs-prod -a -t 0 -i
	@./bin/main-ephemeral --aws-service-catalog-prod -a -t 0 -i
	@./bin/main-ephemeral --manual-registration-rds-test -a -t 0 -i
	@./bin/main-ephemeral --discovery-sqs-test -a -t 0 -i
	@./bin/main-ephemeral --aws-service-catalog-test -a -t 0 -i
	@curl -s http://localhost:4040/api/tunnels | \
        jq '["NAME","PUBLIC URL"], ["------","------------------------------"], (.tunnels[] | [ .name, .public_url ]) | @tsv' -r

.PHONY: ephemeral-run-test-env
ephemeral-run-test-env:
	@./bin/main-ephemeral --env-ephemeral

.PHONY: ephemeral-run-all-demos
ephemeral-run-all-demos: ephemeral-run-setup-env ephemeral-run-services-demos
	@:

.PHONY: ephemeral-lint
ephemeral-lint:
	shellcheck hack/setup-ephemeral.sh -P . -x

.PHONY: ephemeral-book
ephemeral-book:
	@(cd docs/ephemeral && mdbook build)

