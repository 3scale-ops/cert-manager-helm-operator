# Install

## Manual deploy

To manually install the operator (on all its dependant resources) on default
namespace `cert-manager-helm-operator-system` without using OLM, you can use
the following make target:

```bash
make deploy
```

* Then create any [OperatorConfig resource type](../config/samples/operator_v1alpha1_operatorconfig.yaml).

```yaml
apiVersion: operator.cert-manager.io/v1alpha1
kind: OperatorConfig
metadata:
  name: example
spec:
  podDnsConfig:
    nameservers:
      - 1.1.1.1
      - 8.8.8.8
  resources:
    requests:
      cpu: 10m
      memory: 150Mi
    limits:
      cpu: 100m
      memory: 500Mi
```

* Once tested, delete created operator resources using the following make target:

```bash
make undeploy
```

## OLM manual deploy

If you want to install a specific version of the operator **manually** via OLM

* Deploy with `operator-sdk` using the following command:

```bash
operator-sdk run bundle quay.io/3scale/cert-manager-helm-operator-bundle:v1.7.2
```

* Then create any [OperatorConfig resource type](../config/samples/operator_v1alpha1_operatorconfig.yaml):

```yaml
apiVersion: operator.cert-manager.io/v1alpha1
kind: OperatorConfig
metadata:
  name: example
spec:
  resources:
    requests:
      cpu: 10m
      memory: 150Mi
    limits:
      cpu: 100m
      memory: 500Mi
```

* If you want to test an operator upgrade of a newer version, execute for example:

```bash
operator-sdk run bundle-upgrade quay.io/3scale/cert-manager-helm-operator-bundle:v1.7.3
```

## OLM automatic deploy

If you want to install the operator via OLM on an **automatic** way subscribing
to a catalog, you can need to follow the following steps.

* First you need to deploy an specific `CatalogSource` in which operator releases will be published:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: cert-manager-helm-operator-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: quay.io/3scale/cert-manager-helm-operator-catalog:latest
  displayName: CertManager Helm Operator
  updateStrategy:
    registryPoll:
      interval: 30m
```

* Then you need to create an `OperatorGroup`, so you set the target namespaces in which the cert-manager-helm-operator will watch for `OperatorConfig` custom resources (so it will be set operator ENVVAR `WATCH_NAMESPACE`):

```yaml
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: cert-manager
spec:
  targetNamespaces:
    - cert-manager
```

* Finally create an operator `Subscription` on a given channel (`alpha`/`stable`) with `Automatic`/`Manual` installation (with `Manual` it will ask
you confirmation to install an operator upgrade):

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cert-manager-helm-operator
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: cert-manager-helm-operator
  source: cert-manager-helm-operator-catalog
  sourceNamespace: openshift-marketplace
```

* Then create any [OperatorConfig resource type](../config/samples/operator_v1alpha1_operatorconfig.yaml):

```yaml
apiVersion: operator.cert-manager.io/v1alpha1
kind: OperatorConfig
metadata:
  name: example
spec:
  installCRDs: false
  prometheus:
    enabled: true
    servicemonitor:
      enabled: true
      targetPort: 9402
      path: /metrics
      interval: 30s
  podDnsConfig:
    nameservers:
      - 1.1.1.1
      - 8.8.8.8
```