.PHONY: all
all: setup run-all-demos
	@:

.PHONY: run-all-demos
run-all-demos: build
	@./bin/main -0 -a -t 0 -i
	@./bin/main -1 -a -t 0 -i
	@./bin/main -2 -a -t 0 -i
	@./bin/main -3 -a -t 0 -i

binfolder:
	@mkdir -p ./bin

.PHONY: build
build: binfolder
	@go build -o ./bin/main cmd/main.go

.PHONY: run-env-setup
run-env-setup: build primazactl
	./bin/main --env-setup -a -t 3s -i

.PHONY: run-manual-registration
run-manual-registration: build
	./bin/main --manual-registration-rds

.PHONY: run-discovery-sqs
run-discovery-sqs: build
	./bin/main --discovery-sqs

.PHONY: run-aws-service-catalog
run-aws-service-catalog: build
	./bin/main --aws-service-catalog -i

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

SKIP_BITWARDEN ?= false
SKIP_AWS ?= false

.PHONY: setup
setup: build primazactl
	SKIP_BITWARDEN=$(SKIP_BITWARDEN) SKIP_AWS=$(SKIP_AWS) ./hack/setup.sh

.PHONY: clean
clean:
	./hack/cleanup_aws.sh

.PHONY: book
book:
	@(cd docs && mdbook build)
