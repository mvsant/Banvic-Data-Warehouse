set +e

kubectl apply -f postgres-secret.yaml && sleep 2
kubectl get secret postgres-credentials

kubectl apply -f airflow-meltano-rbac.yaml
kubectl get role,rolebinding -n meltano
docker build -t meltano-pipeline:v1 . && sleep 5
kubectl apply -f meltano-inspector.yaml && sleep 5
kubectl get pod pvc-inspector -n meltano

kubectl cp extract/ meltano/pvc-inspector:/project/

kubectl exec -it pvc-inspector -n meltano -- ls -la /project/extract/
kubectl delete -f meltano-inspector.yaml 
kubectl delete jobs --all -n meltano && sleep 2

kubectl exec -it banvic-release-worker-0 -n airflow -c worker -- /bin/bash -c '
  airflow connections add "Banvic_Postgres" \
    --conn-type "postgres" \
    --conn-host "postgres-service.postgres.svc.cluster.local" \
    --conn-login "$POSTGRES_USER" \
    --conn-password "$POSTGRES_PASSWORD" \
    --conn-schema "$POSTGRES_DB" \
    --conn-port 5432
'

kubectl apply -f postgres-secret.yaml -n airflow && sleep 2
kubectl delete statefulset banvic-release-worker -n airflow && sleep 2
kubectl delete statefulset banvic-release-triggerer -n airflow && sleep 2

helm upgrade --install banvic-release apache-airflow/airflow \
  --namespace airflow \
  --create-namespace \
  -f airflow-values.yaml


kubectl exec -it deployment/banvic-release-worker -n airflow -- env | grep POSTGRES 

echo "Run: bash inspect.sh then cd /project/extract && ls -la to check the files"

