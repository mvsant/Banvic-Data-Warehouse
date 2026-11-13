#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export KUBECONFIG="$(terraform -chdir="$repo_root/terraform/kind" output -raw kubeconfig_path)"

kubectl run meltano-data-inspector \
  --rm -i -t \
  --restart=Never \
  --namespace=meltano \
  --image=busybox \
  --overrides='{"spec":{"volumes":[{"name":"meltano-data","persistentVolumeClaim":{"claimName":"meltano-data-pvc"}}],"containers":[{"name":"inspector","image":"busybox","command":["sh","-c","ls -la /project/extract && sleep 3600"],"stdin":true,"tty":true,"volumeMounts":[{"name":"meltano-data","mountPath":"/project/extract","readOnly":true}]}]}}'
