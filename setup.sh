#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export KUBECONFIG="$repo_root/kind/kubeconfig"

kubectl cluster-info --context kind-banvic >/dev/null
kubectl get pvc meltano-csv-pvc -n meltano >/dev/null

docker build -t meltano-pipeline:v1 "$repo_root"
kind load docker-image meltano-pipeline:v1 --name banvic

kubectl apply -f "$repo_root/meltano-inspector.yaml"
cleanup() {
  kubectl delete -f "$repo_root/meltano-inspector.yaml" --ignore-not-found
}
trap cleanup EXIT

kubectl wait --for=condition=Ready pod/pvc-inspector -n meltano --timeout=120s
kubectl cp "$repo_root/extract/." meltano/pvc-inspector:/project/extract/
kubectl exec pvc-inspector -n meltano -- ls -la /project/extract/
