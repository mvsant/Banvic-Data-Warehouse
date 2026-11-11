#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kind_terraform_root="$repo_root/terraform/kind"
export KUBECONFIG="$kind_terraform_root/kubeconfig"
cluster_context="kind-banvic-warehouse"

for filename in \
  agencias.csv clientes.csv colaborador_agencia.csv colaboradores.csv \
  contas.csv propostas_credito.csv transacoes.csv; do
  if [[ ! -s "$repo_root/data/$filename" ]]; then
    echo "Required CSV is missing or empty: data/$filename" >&2
    exit 1
  fi
done

kubectl cluster-info --context "$cluster_context" >/dev/null
kubectl get pvc meltano-data-pvc -n meltano >/dev/null

docker build -t meltano-pipeline:v1 -f "$repo_root/meltano/Dockerfile" "$repo_root/meltano"
terraform -chdir="$kind_terraform_root" apply -input=false

kubectl apply -f "$repo_root/k8s/meltano/data-loader.yaml"
cleanup() {
  kubectl delete -f "$repo_root/k8s/meltano/data-loader.yaml" --ignore-not-found
}
trap cleanup EXIT

kubectl wait --for=condition=Ready pod/meltano-data-loader -n meltano --timeout=120s
kubectl cp "$repo_root/data/." meltano/meltano-data-loader:/project/data/
kubectl exec meltano-data-loader -n meltano -- sh -ec '
  for filename in agencias.csv clientes.csv colaborador_agencia.csv colaboradores.csv contas.csv propostas_credito.csv transacoes.csv; do
    test -s "/project/data/$filename"
  done
  ls -la /project/data/
'
