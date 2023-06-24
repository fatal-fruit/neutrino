#!/usr/bin/make -f

VERSION := $(shell echo $(shell git describe --tags) | sed 's/^v//')
COMMIT := $(shell git log -1 --format='%H')
DOCKER := $(shell which docker)
BUILDDIR ?= $(CURDIR)/build
LEDGER_ENABLED ?= true

# ********** Golang configs **********

export GO111MODULE = on

GO_MAJOR_VERSION = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f1)
GO_MINOR_VERSION = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f2)

# ********** process build tags **********

build_tags = netgo
ifeq ($(LEDGER_ENABLED),true)
  ifeq ($(OS),Windows_NT)
    GCCEXE = $(shell where gcc.exe 2> NUL)
    ifeq ($(GCCEXE),)
      $(error gcc.exe not installed for ledger support, please install or set LEDGER_ENABLED=false)
    else
      build_tags += ledger
    endif
  else
    UNAME_S = $(shell uname -s)
    ifeq ($(UNAME_S),OpenBSD)
      $(warning OpenBSD detected, disabling ledger support (https://github.com/cosmos/cosmos-sdk/issues/1988))
    else
      GCC = $(shell command -v gcc 2> /dev/null)
      ifeq ($(GCC),)
        $(error gcc not installed for ledger support, please install or set LEDGER_ENABLED=false)
      else
        build_tags += ledger
      endif
    endif
  endif
endif

ifeq (cleveldb,$(findstring cleveldb,$(NEUTRINO_BUILD_OPTIONS)))
  build_tags += gcc cleveldb
else ifeq (rocksdb,$(findstring rocksdb,$(NEUTRINO_BUILD_OPTIONS)))
  build_tags += gcc rocksdb
endif
build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

whitespace :=
whitespace := $(whitespace) $(whitespace)
comma := ,
build_tags_comma_sep := $(subst $(whitespace),$(comma),$(build_tags))

# ********** process linker flags **********

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=neutrino \
		  -X github.com/cosmos/cosmos-sdk/version.AppName=neutrinod \
		  -X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
		  -X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
		  -X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags_comma_sep)"

ifeq (cleveldb,$(findstring cleveldb,$(NEUTRINO_BUILD_OPTIONS)))
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=cleveldb
else ifeq (rocksdb,$(findstring rocksdb,$(NEUTRINO_BUILD_OPTIONS)))
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=rocksdb
endif
ifeq (,$(findstring nostrip,$(NEUTRINO_BUILD_OPTIONS)))
  ldflags += -w -s
endif
ifeq ($(LINK_STATICALLY),true)
	ldflags += -linkmode=external -extldflags "-Wl,-z,muldefs -static"
endif
ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))

BUILD_FLAGS := -tags '$(build_tags)' -ldflags '$(ldflags)'
# check for nostrip option
ifeq (,$(findstring nostrip,$(NEUTRINO_BUILD_OPTIONS)))
  BUILD_FLAGS += -trimpath
endif

all: lint test install


###############################################################################
###                                  Build                                  ###
###############################################################################

install: enforce-go-version
	@echo "Installing neutrinod..."
	go install -mod=readonly $(BUILD_FLAGS) ./cmd/neutrinod

build: enforce-go-version
	@echo "Building neutrinod..."
	go build $(BUILD_FLAGS) -o $(BUILDDIR)/ ./cmd/neutrinod

enforce-go-version:
	@echo "Go version: $(GO_MAJOR_VERSION).$(GO_MINOR_VERSION)"
ifneq ($(GO_MINOR_VERSION),20)
	@echo "Go version 1.20 is required"
	@exit 1
endif

clean:
	rm -rf $(CURDIR)/artifacts/

distclean: clean
	rm -rf vendor/


###############################################################################
###                                Linting                                  ###
###############################################################################
golangci_lint_cmd=golangci-lint
golangci_version=v1.52.2

lint:
	@echo "--> Running linter"
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(golangci_version)
	@$(golangci_lint_cmd) run --timeout=10m

lint-fix:
	@echo "--> Running linter"
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(golangci_version)
	@$(golangci_lint_cmd) run --fix --out-format=tab --issues-exit-code=0

format:
	@go install mvdan.cc/gofumpt@latest
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(golangci_version)
	find . -name '*.go' -type f -not -path "./vendor*" -not -path "*.git*" -not -path "./client/docs/statik/statik.go" -not -path "./tests/mocks/*" -not -name "*.pb.go" -not -name "*.pb.gw.go" -not -name "*.pulsar.go" -not -path "./crypto/keys/secp256k1/*" | xargs gofumpt -w -l
	$(golangci_lint_cmd) run --fix
.PHONY: format

###############################################################################
###                                Localnet                                 ###
###############################################################################

start-localnet: build
	rm -rf ~/.neutrinod-liveness
	./build/neutrinod init liveness --chain-id neutrino-1 --default-denom uneutrino --home ~/.neutrinod-liveness
	./build/neutrinod config chain-id neutrino-1 --home ~/.neutrinod-liveness
	./build/neutrinod config keyring-backend test --home ~/.neutrinod-liveness
	./build/neutrinod keys add val --home ~/.neutrinod-liveness
	./build/neutrinod genesis add-genesis-account val 10000000000000000000000000uneutrino --home ~/.neutrinod-liveness --keyring-backend test
	./build/neutrinod genesis gentx val 1000000000uneutrino --chain-id neutrino-1 --home ~/.neutrinod-liveness
	./build/neutrinod genesis collect-gentxs --home ~/.neutrinod-liveness
	sed -i.bak'' 's/minimum-gas-prices = ""/minimum-gas-prices = "0uneutrino"/' ~/.neutrinod-liveness/config/app.toml
	./build/neutrinod start --home ~/.neutrinod-liveness --x-crisis-skip-assert-invariants

###############################################################################
###                           Tests & Simulation                            ###
###############################################################################
PACKAGES_UNIT=$(shell go list ./... | grep -v -e '/tests/e2e')
PACKAGES_E2E=$(shell cd tests/e2e && go list ./... | grep '/e2e')
TEST_PACKAGES=./...
TEST_TARGETS := test-unit test-e2e

test-unit: ARGS=-timeout=5m -tags='norace'
test-unit: TEST_PACKAGES=$(PACKAGES_UNIT)
test-e2e: ARGS=-timeout=25m -v
test-e2e: TEST_PACKAGES=$(PACKAGES_E2E)
$(TEST_TARGETS): run-tests

run-tests:
ifneq (,$(shell which tparse 2>/dev/null))
	@echo "--> Running tests"
	@go test -mod=readonly -json $(ARGS) $(TEST_PACKAGES) | tparse
else
	@echo "--> Running tests"
	@go test -mod=readonly $(ARGS) $(TEST_PACKAGES)
endif