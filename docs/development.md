# Development

## Initial bootstrap

All operator files were initally bootstraped using `operator-sdk:v1.20.0` at [feat: initial bootstrap](https://github.com/3scale-ops/cert-manager-helm-operator/pull/1/commits/cb256e7afe3e0923bc2582357ffde488daf6da85):

```bash
$ operator-sdk init \
  --plugins helm \
  --group operator \
  --domain cert-manager.io \
  --kind OperatorConfig \
  --version v1alpha1 \
  --helm-chart=cert-manager \
  --helm-chart-repo="https://charts.jetstack.io" \
  --helm-chart-version=1.7.2
```

And then, the most important change done on predefined files was the operator `ClusterRole`, which needed extra permissions in order to be able to create all resources created by the Helm Chart [fix: add missing rbac permissions](https://github.com/3scale-ops/cert-manager-helm-operator/pull/1/commits/a34041fd77133d8c517ac8525a16fa0a92e0b58b).

The rest of the changes are mostly cosmetic, a kind of k8s-operator-olm envelope for the real Helm Chart that will be downloaded dynamically using helm chart version on every operator image build at [helm-charts](helm-charts/).

## Run it

To run the operator locally without creating any new image:

* You can run the operator locally watching all namespaces (default behaviour):

```bash
make run
```

* Or watching a specific namespace using envvar `WATCH_NAMESPACE`:

```bash
make run WATCH_NAMESPACE=example
```
