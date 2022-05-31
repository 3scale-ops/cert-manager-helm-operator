# helm-charts

This folder is used by the makefile targets to download the latest version of the helm chart.

```
Download Helm Chart
  download-helm-chart  Download original helm chart into operator directory helm-charts/
  render-cdrs-from-helm-chart  Generates the CRD definitions from the existing helm chart
  helm-chart       Downloads and generate the complete helm chart used by the operator
```