kubectl run pvc-inspector --rm -i --tty -n meltano \
  --image=busybox \
  --overrides='
  {
    "spec": {
      "volumes": [
        {
          "name": "csv-ingestion-volume",
          "persistentVolumeClaim": {
            "claimName": "meltano-csv-pvc"
          }
        }
      ],
      "containers": [
        {
          "name": "inspector",
          "image": "busybox",
          "args": ["sh"],
          "stdin": true,
          "tty": true,
          "volumeMounts": [
            {
              "name": "csv-ingestion-volume",
              "mountPath": "/project/extract"
            }
          ]
        }
      ]
    }
  }'


