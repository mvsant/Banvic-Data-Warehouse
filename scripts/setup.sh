#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kind_terraform_root="$repo_root/terraform/kind"
export KUBECONFIG="$kind_terraform_root/kubeconfig"
cluster_context="kind-banvic-warehouse"
cluster_name="banvic-warehouse"
kind_bin="${KIND_BIN:-kind}"
export TF_VAR_airflow_dags_host_path="$repo_root/airflow/dags"
export TF_VAR_source_data_host_path="$repo_root/data"

for filename in \
  agencias.csv clientes.csv colaborador_agencia.csv colaboradores.csv \
  contas.csv propostas_credito.csv transacoes.csv; do
  if [[ ! -s "$repo_root/data/$filename" ]]; then
    echo "Required CSV is missing or empty: data/$filename" >&2
    exit 1
  fi
done

docker_config="$(mktemp -d)"
trap 'rm -rf -- "$docker_config"' EXIT
printf '{}\n' > "$docker_config/config.json"
DOCKER_CONFIG="$docker_config" docker build \
  -t meltano-pipeline:v1 \
  -f "$repo_root/meltano/Dockerfile" \
  "$repo_root/meltano"
rm -rf -- "$docker_config"
trap - EXIT

if "$kind_bin" get clusters | grep -Fxq "$cluster_name"; then
  kind_version="$("$kind_bin" version | sed -n 's/^kind v\([0-9][0-9.]*\).*/\1/p')"
  if [[ ! "$kind_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Could not determine the Kind CLI version. Set KIND_BIN to Kind v0.32.0 or newer, then rerun this script." >&2
    exit 1
  fi
  kind_major="${BASH_REMATCH[1]}"
  kind_minor="${BASH_REMATCH[2]}"
  if (( kind_major == 0 && kind_minor < 32 )); then
    echo "Kind v${kind_version} cannot load images into this cluster's containerd config v4." >&2
    echo "Set KIND_BIN to a Kind v0.32.0 or newer binary, then rerun this script. No cluster recreation is needed." >&2
    exit 1
  fi
  "$kind_bin" load docker-image meltano-pipeline:v1 --name "$cluster_name"
else
  terraform -chdir="$kind_terraform_root" apply -input=false
fi

kubectl cluster-info --context "$cluster_context" >/dev/null
if ! kubectl get pvc meltano-data-pvc -n meltano >/dev/null 2>&1; then
  echo "Meltano PVC is not available. If Kind was recreated, apply terraform/platform and rerun this script." >&2
  exit 1
fi

loader_name="meltano-data-loader-$$"
cleanup_loader() {
  kubectl delete pod "$loader_name" -n meltano --ignore-not-found --wait=true >/dev/null
}
trap cleanup_loader EXIT

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $loader_name
  namespace: meltano
spec:
  restartPolicy: Never
  containers:
    - name: data-loader
      image: meltano-pipeline:v1
      imagePullPolicy: IfNotPresent
      command: ["/bin/sh", "-ec", "sleep 600"]
      volumeMounts:
        - name: meltano-data
          mountPath: /project/extract
  volumes:
    - name: meltano-data
      persistentVolumeClaim:
        claimName: meltano-data-pvc
EOF

kubectl wait --for=condition=Ready "pod/$loader_name" -n meltano --timeout=120s
for filename in \
  agencias.csv clientes.csv colaborador_agencia.csv colaboradores.csv \
  contas.csv propostas_credito.csv transacoes.csv; do
  sed -E \
    's/([0-9]{4}-[0-9]{2}-[0-9]{2}) ([0-9]{2}:[0-9]{2}:[0-9]{2}) UTC/\1T\2+00:00/g' \
    "$repo_root/data/$filename" |
    kubectl exec -i -n meltano "$loader_name" -- \
      sh -c "cat > /project/extract/$filename"
  kubectl exec -n meltano "$loader_name" -- \
    test -s "/project/extract/$filename"
done

echo "Copied current data/*.csv files into meltano-data-pvc."
