# VERSION defines the project version for the bundle.
# Update this value when you upgrade the version of your project.
# To re-generate a bundle for another specific version without changing the standard setup, you can:
# - use the VERSION as arg of the bundle target (e.g make bundle VERSION=0.0.2)
# - use environment variables to overwrite this value (e.g export VERSION=0.0.2)
VERSION ?= 1.7.2

# CHANNELS define the bundle channels used in the bundle.
# Add a new line here if you would like to change its default config. (E.g CHANNELS = "candidate,fast,stable")
# To re-generate a bundle for other specific channels without changing the standard setup, you can:
# - use the CHANNELS as arg of the bundle target (e.g make bundle CHANNELS=candidate,fast,stable)
# - use environment variables to overwrite this value (e.g export CHANNELS="candidate,fast,stable")
ifneq ($(origin CHANNELS), undefined)
BUNDLE_CHANNELS := --channels=$(CHANNELS)
endif

# DEFAULT_CHANNEL defines the default channel used in the bundle.
# Add a new line here if you would like to change its default config. (E.g DEFAULT_CHANNEL = "stable")
# To re-generate a bundle for any other default channel without changing the default setup, you can:
# - use the DEFAULT_CHANNEL as arg of the bundle target (e.g make bundle DEFAULT_CHANNEL=stable)
# - use environment variables to overwrite this value (e.g export DEFAULT_CHANNEL="stable")
ifneq ($(origin DEFAULT_CHANNEL), undefined)
BUNDLE_DEFAULT_CHANNEL := --default-channel=$(DEFAULT_CHANNEL)
endif
BUNDLE_METADATA_OPTS ?= $(BUNDLE_CHANNELS) $(BUNDLE_DEFAULT_CHANNEL)

# IMAGE_TAG_BASE defines the docker.io namespace and part of the image name for remote images.
# This variable is used to construct full image tags for bundle and catalog images.
#
# For example, running 'make bundle-build bundle-push catalog-build catalog-push' will build and push both
# cert-manager.io/cert-manager-operator-bundle:$VERSION and cert-manager.io/cert-manager-operator-catalog:$VERSION.
IMAGE_TAG_BASE ?= quay.io/3scale/cert-manager-helm-operator

# BUNDLE_IMG defines the image:tag used for the bundle.
# You can use it as an arg. (E.g make bundle-build BUNDLE_IMG=<some-registry>/<project-name-bundle>:<tag>)
BUNDLE_IMG ?= $(IMAGE_TAG_BASE)-bundle:v$(VERSION)

# Image URL to use all building/pushing image targets
IMG ?= $(IMAGE_TAG_BASE):v$(VERSION)

all: container-build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build

run: download-helm-chart helm-operator ## Run against the configured Kubernetes cluster in ~/.kube/config
	$(HELM_OPERATOR) run

CONTAINER_RUNTIME ?= docker

container-build: download-helm-chart ## Build docker image with the manager.
	$(CONTAINER_RUNTIME) build -t ${IMG} .

container-push: ## Push docker image with the manager.
	$(CONTAINER_RUNTIME) push ${IMG}

##@ Deployment

install: kustomize ## Install CRDs into the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

uninstall: kustomize ## Uninstall CRDs from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl delete -f -

deploy: kustomize ## Deploy controller to the K8s cluster specified in ~/.kube/config.
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | kubectl apply -f -

undeploy: ## Undeploy controller from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/default | kubectl delete -f -

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m | sed 's/x86_64/amd64/')

.PHONY: kustomize
KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize: ## Download kustomize locally if necessary.
ifeq (,$(wildcard $(KUSTOMIZE)))
ifeq (,$(shell which kustomize 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(KUSTOMIZE)) ;\
	curl -sSLo - https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v3.8.7/kustomize_v3.8.7_$(OS)_$(ARCH).tar.gz | \
	tar xzf - -C bin/ ;\
	}
else
KUSTOMIZE = $(shell which kustomize)
endif
endif

.PHONY: helm-operator
HELM_OPERATOR = $(shell pwd)/bin/helm-operator
helm-operator: ## Download helm-operator locally if necessary, preferring the $(pwd)/bin path over global if both exist.
ifeq (,$(wildcard $(HELM_OPERATOR)))
ifeq (,$(shell which helm-operator 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(HELM_OPERATOR)) ;\
	curl -sSLo $(HELM_OPERATOR) https://github.com/operator-framework/operator-sdk/releases/download/$(OPERATOR_SDK_RELEASE)/helm-operator_$(OS)_$(ARCH) ;\
	chmod +x $(HELM_OPERATOR) ;\
	}
else
HELM_OPERATOR = $(shell which helm-operator)
endif
endif

.PHONY: bundle
bundle: operator-sdk kustomize ## Generate bundle manifests and metadata, then validate generated files.
	$(OPERATOR_SDK) generate kustomize manifests -q
	cd config/manager && $(KUSTOMIZE) edit set image controller=$(IMG)
	$(KUSTOMIZE) build config/manifests | $(OPERATOR_SDK) generate bundle -q --overwrite --version $(VERSION) $(BUNDLE_METADATA_OPTS)
	$(OPERATOR_SDK) bundle validate ./bundle

.PHONY: bundle-build
bundle-build: ## Build the bundle image.
	$(CONTAINER_RUNTIME) build -f bundle.Dockerfile -t $(BUNDLE_IMG) .

.PHONY: bundle-push
bundle-push: ## Push the bundle image.
	$(MAKE) container-push IMG=$(BUNDLE_IMG)

.PHONY: opm
OPM = ./bin/opm
opm: ## Download opm locally if necessary.
ifeq (,$(wildcard $(OPM)))
ifeq (,$(shell which opm 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(OPM)) ;\
	curl -sSLo $(OPM) https://github.com/operator-framework/operator-registry/releases/download/v1.15.1/$(OS)-$(ARCH)-opm ;\
	chmod +x $(OPM) ;\
	}
else
OPM = $(shell which opm)
endif
endif

# A comma-separated list of bundle images (e.g. make catalog-build BUNDLE_IMGS=example.com/operator-bundle:v0.1.0,example.com/operator-bundle:v0.2.0).
# These images MUST exist in a registry and be pull-able.
BUNDLE_IMGS ?= $(BUNDLE_IMG)

# The image tag given to the resulting catalog image (e.g. make catalog-build CATALOG_IMG=example.com/operator-catalog:v0.2.0).
CATALOG_IMG ?= $(IMAGE_TAG_BASE)-catalog:v$(VERSION)

# Custom default catalog base image to append bundles to
CATALOG_BASE_IMG ?= $(IMAGE_TAG_BASE)-catalog:latest

# Set CATALOG_BASE_IMG to an existing catalog image tag to add $BUNDLE_IMGS to that image.
ifneq ($(origin CATALOG_BASE_IMG), undefined)
FROM_INDEX_OPT := --from-index $(CATALOG_BASE_IMG)
endif

# Build a catalog image by adding bundle images to an empty catalog using the operator package manager tool, 'opm'.
# This recipe invokes 'opm' in 'semver' bundle add mode. For more information on add modes, see:
# https://github.com/operator-framework/community-operators/blob/7f1438c/docs/packaging-operator.md#updating-your-existing-operator
.PHONY: catalog-build
catalog-build: opm ## Build a catalog image.
	$(OPM) index add --container-tool $(CONTAINER_RUNTIME) --mode semver --tag $(CATALOG_IMG) --bundles $(BUNDLE_IMGS) $(FROM_INDEX_OPT)

# Push the catalog image.
.PHONY: catalog-push
catalog-push: ## Push a catalog image.
	$(MAKE) container-push IMG=$(CATALOG_IMG)

#############################################
#### Custom Targets with extra binaries #####
#############################################

# Download operator-sdk binary if necessary
HELM_RELEASE = v3.8.2
HELM = $(shell pwd)/bin/helm-$(HELM_RELEASE)
HELM_DL_URL = https://get.helm.sh/helm-$(HELM_RELEASE)-$(OS)-$(ARCH).tar.gz
helm:
ifeq (,$(wildcard $(HELM)))
ifeq (,$(shell which $(HELM) 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(shell pwd)/bin ;\
	curl -sL $(HELM_DL_URL) | tar -C $(shell pwd)/bin --strip-components 1 -zx $(OS)-$(ARCH)/helm;\
	mv $(shell pwd)/bin/helm $(HELM) && chmod +x $(HELM) ;\
	}
else
HELM = $(shell which $(HELM))
endif
endif

# Download operator-sdk binary if necessary
OPERATOR_SDK_RELEASE = v1.16.0
OPERATOR_SDK = $(shell pwd)/bin/operator-sdk-$(OPERATOR_SDK_RELEASE)
OPERATOR_SDK_DL_URL = https://github.com/operator-framework/operator-sdk/releases/download/$(OPERATOR_SDK_RELEASE)/operator-sdk_$(OS)_$(ARCH)
operator-sdk:
ifeq (,$(wildcard $(OPERATOR_SDK)))
ifeq (,$(shell which $(OPERATOR_SDK) 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(shell pwd)/bin ;\
	curl -sL -o $(OPERATOR_SDK) $(OPERATOR_SDK_DL_URL) ;\
	chmod +x $(OPERATOR_SDK) ;\
	}
else
OPERATOR_SDK = $(shell which $(OPERATOR_SDK))
endif
endif

# Download kind locally if necessary
KIND_RELEASE = v0.11.1
KIND = $(shell pwd)/bin/kind-$(KIND_RELEASE) 2>/dev/null
KIND_DL_URL = https://github.com/kubernetes-sigs/kind/releases/download/$(KIND_RELEASE)/kind-$(OS)-$(ARCH)
kind:
ifeq (,$(wildcard $(KIND)))
ifeq (,$(shell which $(KIND) 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(shell pwd)/bin ;\
	curl -sL -o $(KIND) $(KIND_DL_URL) ;\
	chmod +x $(KIND) ;\
	}
else
KIND = $(shell which $(KIND))
endif
endif

# Download kuttl locally if necessary for e2e tests
KUTTL_RELEASE = 0.9.0
KUTTL = $(shell pwd)/bin/kuttl-v$(KUTTL_RELEASE)
KUTTL_DL_URL = https://github.com/kudobuilder/kuttl/releases/download/v$(KUTTL_RELEASE)/kubectl-kuttl_$(KUTTL_RELEASE)_$(OS)_x86_64
kuttl:
ifeq (,$(wildcard $(KUTTL)))
ifeq (,$(shell which $(KUTTL) 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(shell pwd)/bin ;\
	curl -sL -o $(KUTTL) $(KUTTL_DL_URL) ;\
	chmod +x $(KUTTL) ;\
	}
else
KUTTL = $(shell which $(KUTTL))
endif
endif

####################################################
#### Custom Targets clones original helm chart #####
####################################################
##@ Download Helm Chart

HELM_CHARTS_PATH="$(PWD)/helm-charts"
HELM_CHART_NAME="cert-name"
HELM_CHART_REPO="https://charts.jetstack.io"
HELM_CHART_VERSION=$(shell echo $(VERSION) | sed 's/\([0-9.]\+\).*/\1/g')
download-helm-chart: helm ## Download original helm chart into operator directory helm-charts/
	@$(HELM) repo add jetstack $(HELM_CHART_REPO) >/dev/null \
		|| { echo "Unable to add $(HELM_CHART_REPO) reposirtory"; exit 1; }
	@test -d $(HELM_CHARTS_PATH)/cert-manager \
		|| { mkdir -p $(HELM_CHARTS_PATH)/cert-manager; } \
		&& { find $(HELM_CHARTS_PATH)/cert-manager -delete; }
	@$(HELM) pull \
		--untar --untardir $(HELM_CHARTS_PATH) \
		--version=$(HELM_CHART_VERSION) jetstack/cert-manager \
		&& echo "jetstack/cert-manager@$(HELM_CHART_VERSION) downloaded to $(HELM_CHARTS_PATH)"
	@sed -i "s|installCRDs: [^ ]*|installCRDs: false|g" \
		$(HELM_CHARTS_PATH)/cert-manager/values.yaml

TMP_FOLDER="$(PWD)/tmp"

render-cdrs-from-helm-chart: helm download-helm-chart ## Generates the CRD definitions from the existing helm chart
	@test ! -d $(TMP_FOLDER)/render || find $(TMP_FOLDER)/render -delete;
	@$(HELM) template --set installCRDs=true --include-crds $(HELM_CHARTS_PATH)/cert-manager \
		| awk -vout=$(TMP_FOLDER)/render -F": " \
			'$$0~/^# Source: /{file=out"/"$$2; system ("mkdir -p $$(dirname "file"); echo ""--- >> "file)} $$0!~/^#/ && $$0!="---"{print $$0 >> file}';
	@cp  $(TMP_FOLDER)/render/cert-manager/templates/crds.yaml $(PWD)/config/crd/bases/cert-manager.io_crds.yaml
	@cd  $(PWD)/config/crd && $(KUSTOMIZE) edit add resource bases/cert-manager.io_crds.yaml
	@test ! -d $(TMP_FOLDER)/render || find $(TMP_FOLDER)/render -delete;

helm-chart: helm download-helm-chart render-cdrs-from-helm-chart ## Downloads and generate the complete helm chart used by the operator

####################################################
#### Custom Targets to publish release catalog #####
####################################################
##@ Release Catalog

prepare-alpha-release: bundle ## Prepare alpha release

prepare-stable-release: bundle ## Prepare stable release
	$(MAKE) bundle CHANNELS=alpha,stable DEFAULT_CHANNEL=alpha

catalog-retag-latest:
	$(CONTAINER_RUNTIME) tag $(CATALOG_IMG) $(CATALOG_BASE_IMG)
	$(MAKE) container-push IMG=$(CATALOG_BASE_IMG)

bundle-publish: test-e2e bundle-build bundle-push catalog-build catalog-push catalog-retag-latest ## Publish new release in catalog

get-new-release:
	@if [[ v$(VERSION) == *"-alpha"* ]]; then echo; \
	elif curl -o /dev/null --fail --silent \
		"$(GH_REPO_RELEASES_URL)/v$(VERSION)"; then echo; \
	else echo "v$(VERSION)"; fi;

###################################################
#### Custom Targets to manually test with Kind ####
###################################################
##@ Testing

kind-create: export KUBECONFIG = ${PWD}/kubeconfig
kind-create: kind ## Creates a k8s kind cluster
ifeq (1, $(shell $(KIND) get clusters | grep kind | wc -l))
	@echo "Kind cluster already exists, doing nothing"
else
	@echo "Creating kind cluster"
	$(KIND) create cluster --wait 5m
endif

kind-delete: kind ## Deletes the k8s kind cluster
	$(KIND) delete cluster

kind-deploy: export KUBECONFIG = ${PWD}/kubeconfig
kind-deploy: container-build kind ## Deploys the operator in the k8s kind cluster
	$(KIND) load docker-image $(IMG)
	$(KUSTOMIZE) build config/testing | kubectl apply -f -
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | kubectl apply -f -

kind-undeploy: export KUBECONFIG = ${PWD}/kubeconfig
kind-undeploy: kind ## Undeploys the operator in the k8s kind cluster
	$(KUSTOMIZE) build config/default | kubectl delete -f -


test-e2e: export KUBECONFIG = ${PWD}/kubeconfig
test-e2e: kuttl kind-create kind-deploy  ## Run kuttl e2e tests in the k8s kind cluster
	$(KUTTL) test