# Cert Manager Helm Operator

[![test](https://github.com/3scale-ops/cert-manager-helm-operator/actions/workflows/test.yaml/badge.svg)](https://github.com/3scale-ops/cert-manager-helm-operator/actions/workflows/test.yaml)
[![build](https://github.com/3scale-ops/cert-manager-helm-operator/actions/workflows/release.yaml/badge.svg)](https://github.com/3scale-ops/cert-manager-helm-operator/actions/workflows/release.yaml)
[![release](https://badgen.net/github/release/3scale-ops/cert-manager-helm-operator)](https://github.com/3scale-ops/cert-manager-helm-operator/releases)
[![license](https://badgen.net/github/license/3scale-ops/cert-manager-helm-operator)](https://github.com/3scale-ops/cert-manager-helm-operator/blob/main/LICENSE)

A Kubernetes Operator based on the Operator SDK (Helm version) to configure **[official cert-manager operator helm chart](https://artifacthub.io/packages/helm/cert-manager/cert-manager)**, so it can be installed via OLM without having to do any change on current Helm Charts.

The usual Helm Chart file `values.yaml`, like:

```yaml
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
resources:
   requests:
     cpu: 10m
     memory: 96Mi
   limits:
     cpu: 100m
     memory: 256Mi
```

Need to be encapsulated into a new custom resource called `OperatorConfig`:

```yaml
apiVersion: operatorconfigs.operator.cert-manager.io/v1alpha1
kind: OperatorConfig
metadata:
  name: cluster
spec:
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
  resources:
   requests:
     cpu: 10m
     memory: 96Mi
   limits:
     cpu: 100m
     memory: 256Mi
```

So the operator will create all helm chart resources, using the custom resource name as a prefix for all resources names.

## Quick release

You can easily generate the operator for any particular version of the Cert
Manager Helm Chart using the `container-build` target with a specific `VERSION`.

- Command

```bash
$ VERSION=1.8.0 make container-build
```
```bash
jetstack/cert-manager@1.8.0 downloaded to /home/rael/gh/3scale-ops/cert-manager-helm-operator/helm-charts
docker build -t quay.io/3scale/cert-manager-helm-operator:v1.8.0 .
Sending build context to Docker daemon  321.4MB
Step 1/5 : FROM quay.io/operator-framework/helm-operator:v1.17.0
 ---> b9a34ccc1cc0
Step 2/5 : ENV HOME=/opt/helm
 ---> Using cache
 ---> 28eeebb8f2d5
Step 3/5 : COPY watches.yaml ${HOME}/watches.yaml
 ---> Using cache
 ---> 8ccd06f07a70
Step 4/5 : COPY helm-charts  ${HOME}/helm-charts
 ---> Using cache
 ---> db4111523af7
Step 5/5 : WORKDIR ${HOME}
 ---> Using cache
 ---> 73f0ce5f4901
Successfully built 73f0ce5f4901
Successfully tagged quay.io/3scale/cert-manager-helm-operator:v1.8.0
```

- Files generated

```bash
$ grep version helm-charts/cert-manager/Chart.yaml
version: v1.8.0
$ tree helm-charts/
helm-charts/
├── README.md
└── cert-manager
    ├── Chart.yaml
    ├── README.md
    ├── templates
    │   ├── NOTES.txt
    │   ├── _helpers.tpl
    │   ├── cainjector-deployment.yaml
...
    │   ├── crds.yaml
    │   ├── deployment.yaml
    │   ├── rbac.yaml
    │   ├── service.yaml
...
    │   ├── webhook-service.yaml
    │   ├── webhook-serviceaccount.yaml
    │   └── webhook-validating-webhook.yaml
    └── values.yaml
```

For more detailed information, check the [documentation](docs/) available.

## Documentation

* [Install](docs/install.md)
* [Development](docs/development.md)
* [Release](docs/release.md)

## Contributing

You can contribute by:

* Raising any issues you find using Cert Manager Helm Operator
* Fixing issues by opening [Pull Requests](https://github.com/3scale-ops/cert-manager-helm-operator/pulls)
* Submitting a patch or opening a PR
* Improving documentation
* Talking about Cert Manager Helm Operator

All bugs, tasks or enhancements are tracked as [GitHub issues](https://github.com/3scale-ops/cert-manager-helm-operator/issues).

## License

Cert Manager Helm Operator is under Apache 2.0 license. See the [LICENSE](LICENSE) file for details.