


helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update


helm install istio-base istio/base --namespace istio-system --create-namespace

## Install CNI
helm install istio-cni istio/cni --version 1.26.2 --namespace istio-system --values ./manifests/istio/istio-cni-values.yaml

## Install Istiod
helm install istiod istio/istiod --version 1.26.2 --namespace istio-system --values ./manifests/istio/istiod-values.yaml

## Install Istio-IngressGateway
helm install istio-gateway istio/gateway --version 1.26.2 --namespace istio-system --values ./manifests/istio/istio-gateway-values.yaml