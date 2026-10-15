# POC: Quarkus lee un JSON de Secret Manager

Un JSON en Secret Manager. External Secrets lo copia a un Secret de Kubernetes con Workload Identity, sin archivo de llave. Quarkus no habla con Google: lee variables con `secretKeyRef` y un archivo montado, y `GET /` devuelve esos valores.

Los cuatro campos son placeholders (`poc-placeholder`, `version-1`, `hola desde el archivo`). El endpoint puede devolverlos. `terraform.tfstate` no se commitea.

La cuenta de gcloud de todos los días no se usa. Cuando toque crear el clúster se pide el login de la cuenta personal. El nodo `e2-standard-2` factura mientras existe: hay que apagarlo el mismo día.

## Árbol

```text
terraform/main.tf
app/
charts/poc/
rotar-etiqueta.sh
```

## Clúster

El shell es fish: los comandos van en una sola línea.

```shell
gcloud config configurations create poc-secretos
gcloud config configurations activate poc-secretos
gcloud auth login
gcloud config set project TU_PROYECTO
gcloud auth application-default login
cd terraform
terraform init
terraform apply -var="project_id=TU_PROYECTO"
gcloud container clusters get-credentials poc-secretos --zone us-central1-a --project TU_PROYECTO
gcloud container clusters describe poc-secretos --zone us-central1-a --project TU_PROYECTO --format='value(location,workloadIdentityConfig.workloadPool)'
```

La zona que imprime `describe` es la de `clusterLocation`.

## Imagen y Helm

```shell
gcloud auth configure-docker us-central1-docker.pkg.dev
docker build -t us-central1-docker.pkg.dev/TU_PROYECTO/poc-secretos/poc:1 app
docker push us-central1-docker.pkg.dev/TU_PROYECTO/poc-secretos/poc:1
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets --version 2.12.0 --namespace external-secrets --create-namespace --set installCRDs=true --set serviceAccount.name=external-secrets --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"=poc-eso@TU_PROYECTO.iam.gserviceaccount.com --wait
helm install poc charts/poc --namespace demo --create-namespace --set projectId=TU_PROYECTO --set clusterLocation=us-central1-a --set clusterName=poc-secretos --set image=us-central1-docker.pkg.dev/TU_PROYECTO/poc-secretos/poc:1 --wait --timeout 10m
```

El correo de la anotación es el output `eso_gsa`. Si la región no es `us-central1`, usa `terraform output region`.

## Demo

```shell
kubectl get clustersecretstore gcp-secret-manager
kubectl get externalsecret poc-secrets -n demo
kubectl get pods -n demo
kubectl port-forward -n demo svc/poc 8080:8080
```

```shell
curl -s localhost:8080
```

```json
{"mongo-root-password":"poc-placeholder","mongo-connection-string":"mongodb://root:poc-placeholder@mongodb.demo.svc.cluster.local:27017/demo?authSource=admin","etiqueta":"version-1","banner":"hola desde el archivo"}
```

```shell
sh rotar-etiqueta.sh version-2 TU_PROYECTO
kubectl get secret poc-secrets -n demo -o jsonpath='{.data.etiqueta}' | base64 -d
echo
curl -s localhost:8080
kubectl rollout restart deployment/poc -n demo
kubectl rollout status deployment/poc -n demo
curl -s localhost:8080
```

Antes del reinicio la respuesta sigue en `version-1`. Después dice `version-2`. El banner no cambia.

## Apagar

```shell
helm uninstall poc -n demo
helm uninstall external-secrets -n external-secrets
kubectl delete ns demo external-secrets
cd terraform
terraform destroy -var="project_id=TU_PROYECTO"
gcloud config configurations activate taciyon
kubectl config use-context gke_taciyon-prod_us-central1_taciyon-prod-autopilot
```

Si el destroy queda a medias:

```shell
gcloud container clusters delete poc-secretos --zone us-central1-a --project TU_PROYECTO
```
