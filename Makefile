.PHONY: all
all: setup build
	@./bin/main -0 -a -t 0 -i
	@./bin/main -1 -a -t 0 -i
	@./bin/main -2 -a -t 0 -i
	@./bin/main -3 -a -t 0 -i

binfolder:
	@mkdir -p ./bin

.PHONY: build
build: binfolder
	@go build -o ./bin/main cmd/main.go

.PHONY: mc-env
mc-env: build primazactl
	@./bin/main -0 -a

.PHONY: manual-reg
manual-reg: build
	@./bin/main -1 -a

.PHONY: discovery
discovery: build
	@./bin/main -2 -a

.PHONY: aws-service-catalog
aws-service-catalog: build
	@./bin/main -3 -a

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
setup:
	SKIP_BITWARDEN=$(SKIP_BITWARDEN) SKIP_AWS=$(SKIP_AWS) ./hack/setup.sh

.PHONY: clean
clean:
	./hack/cleanup_aws.sh

.PHONY: book
book:
	@(cd docs && mdbook build)
