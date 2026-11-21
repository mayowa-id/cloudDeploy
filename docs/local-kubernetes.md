# Local Kubernetes

Run these commands from the repository root in the Linux environment that runs Docker. Install [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) and [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) there first.

```sh
docker build -t clouddeploy:local ./app
kind create cluster --name clouddeploy --wait 120s
kind load docker-image clouddeploy:local --name clouddeploy

kubectl --context kind-clouddeploy apply -f kubernetes/namespace.yaml
kubectl --context kind-clouddeploy apply \
  -f kubernetes/configmap.yaml \
  -f kubernetes/deployment.yaml \
  -f kubernetes/service.yaml
kubectl --context kind-clouddeploy -n clouddeploy rollout status deployment/clouddeploy-api --timeout=120s
kubectl --context kind-clouddeploy -n clouddeploy port-forward service/clouddeploy-api 18080:3000
```

From another terminal, check the Service and release metadata:

```sh
curl --fail http://127.0.0.1:18080/health
curl --fail http://127.0.0.1:18080/ready
curl --fail http://127.0.0.1:18080/version
```

Kubernetes uses `/ready` to decide which Pods can receive traffic and `/health` to decide whether to restart a container. The `instance` field on `/version` shows the Pod name. To verify recovery, delete one Pod by name and watch the Deployment bring the ready count back to three. To verify manual scaling, scale to five replicas and back to three before enabling the autoscaler.

```sh
kubectl --context kind-clouddeploy -n clouddeploy get pods
kubectl --context kind-clouddeploy -n clouddeploy delete pod POD_NAME
kubectl --context kind-clouddeploy -n clouddeploy get pods -w
# Stop the watch with Ctrl+C when all three Pods are ready.
kubectl --context kind-clouddeploy -n clouddeploy scale deployment/clouddeploy-api --replicas=5
kubectl --context kind-clouddeploy -n clouddeploy rollout status deployment/clouddeploy-api --timeout=120s
kubectl --context kind-clouddeploy -n clouddeploy scale deployment/clouddeploy-api --replicas=3
```

## CPU autoscaling on kind

The HorizontalPodAutoscaler targets 70% average CPU utilization relative to the Pods' CPU requests and can run three to six replicas. Install [Metrics Server v0.9.1](https://github.com/kubernetes-sigs/metrics-server/releases/tag/v0.9.1) once on the local kind cluster. The patch permits Metrics Server to scrape kind's self-signed kubelet endpoints for local testing.

```sh
kubectl --context kind-clouddeploy apply -f \
  https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.1/components.yaml
kubectl --context kind-clouddeploy -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl --context kind-clouddeploy -n kube-system rollout status deployment/metrics-server --timeout=180s
kubectl --context kind-clouddeploy apply -f kubernetes/hpa.yaml
kubectl --context kind-clouddeploy -n clouddeploy top pods
kubectl --context kind-clouddeploy -n clouddeploy get hpa
```

Allow time for the first CPU samples. Once enabled, let the HPA manage the replica count. When you're finished with the local cluster, remove it with `kind delete cluster --name clouddeploy`.
