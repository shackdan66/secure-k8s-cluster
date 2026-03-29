# Building Secure K8s Lab

This repo is meant to serve as a guide to get a working secure k8s demo/sandbox environment.

- Lab Diagram
![Kiali Service Graph](images/screenshots/arch.png)

Note: The repo was developed on a Apple Silicon MacBook

The lab assumes the user is familiar with Kubernetes and related technologies.

## Prep and Pre reqs

### CLI Tools

- brew: <https://brew.sh>
- minikube: <https://minikube.sigs.k8s.io/docs/>
- colima: <https://github.com/abiosoft/colima>
- kubectl: <https://kubernetes.io/docs/reference/kubectl/>
- helm: <https://helm.sh>
- yq: <https://github.com/mikefarah/yq>
- istio: <https://istio.io/>

#### Install tools

- install brew: ```/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"```
- install colima: ```brew install colima```
- install minikube: ```brew install minikube```
- install kubectl: ```brew install kubernetes-cli```
- install istioctl: ```brew install istioctl```
- install helm: ```brew install helm```
- install yq: ```brew install yq```
- install helm: ```brew install helm```

## Initial Development On Minikube with Colima on MacOs

```text
colima start --memory 9 --cpu 8
```

```text
minikube start --driver=docker --memory=8192 --cpus=8
```

### Verify pods are started

```text
kubectl get pods -A
NAMESPACE     NAME                                       READY   STATUS    RESTARTS      AGE
kube-system   coredns-674b8bbfcf-dc9dg                   1/1     Running   1 (22s ago)   35s
kube-system   etcd-minikube                              1/1     Running   0             41s
kube-system   kube-apiserver-minikube                    1/1     Running   0             41s
kube-system   kube-controller-manager-minikube           1/1     Running   0             41s
kube-system   kube-proxy-drzq5                           1/1     Running   0             35s
kube-system   kube-scheduler-minikube                    1/1     Running   0             41s
kube-system   storage-provisioner                        1/1     Running   1 (6s ago)    39s
```

## Install Argocd

### Create SSH key for Bitbucket

```text
ssh-keygen -t ed25519 -C "my.name@slalom.com" -f $HOME/.ssh/argocd_bitbucket
```

### add key to agent

```text
eval "$(ssh-agent -s)"

ssh-add ~/.ssh/argocd_bitbucket
```

### Add key to bitbucket

#### Add key to bitbucket repo

- Note the process to add ssh key to repo requires admin access on the repo. If admin access is not available, then fork this repo and add ssh to the Bitbucket user account

1. Select the Repository Settings cog on the left navigation bar.
2. Select Security/Access Keys from the left navigation bar.
3. Clik Add key.
4. In the Add SSH key dialog, provide a Label to help you identify which key you are adding. For example, Argodc or Minkube. A meaningful label will help identify old or unwanted keys in the future.
5. Open the public SSH key - ```cat ~/.ssh/argocd_bitbucket.pub```. The contents will be similar to:

    ```text
    ssh-ed25529 LLoWYaPswHljlkjlkadflkheaqerawrkhjLKJlasdfHGGHL user@slalom.com
    ```

6. Copy the contents of the public key file and paste the key into the Key field of the Add SSH key dialog.
7. Under Expiry, select No expiry to not set an expiry date, or select Expires on and then select the date picker to set a specific date for your SSH key to expire. Note: The default date range for expiry is set to 365 days (one year) from today’s date.
8. Click Add key.

- If the key is added successfully, the dialog will close and the key will be listed on the SSH keys page.
- If you receive the error That SSH key is invalid, check that you copied the entire contents of the public key (.pub file).

#### Add key to bitbucket account

1. Select the Settings cog on the top navigation bar.
2. From the Settings dropdown menu, select Personal Bitbucket settings.
3. Under Security, select SSH keys.
4. Select Add key.
5. In the Add SSH key dialog, provide a Label to help you identify which key you are adding. For example, Argodc or Minkube. A meaningful label will help identify old or unwanted keys in the future.
6. Open the public SSH key file (public keys have the .pub file extension) in a text editor. The public key should be in the .ssh/ directory of your user (or home) directory. The contents will be similar to:

    ```text
    ssh-ed25529 LLoWYaPswHljlkjlkadflkheaqerawrkhjLKJlasdfHGGHL user@slalom.com
    ```

7. Copy the contents of the public key file and paste the key into the Key field of the Add SSH key dialog.
8. Under Expiry, select No expiry to not set an expiry date, or select Expires on and then select the date picker to set a specific date for your SSH key to expire. Note: The default date range for expiry is set to 365 days (one year) from today’s date.
9. Select Add key.

- If the key is added successfully, the dialog will close and the key will be listed on the SSH keys page.
- If you receive the error That SSH key is invalid, check that you copied the entire contents of the public key (.pub file).

#### Check that your SSH authentication works

To test that the SSH key was added successfully, open a terminal on your device and run the following command:

```text
ssh -T git@bitbucket.org
```

If SSH can successfully connect with Bitbucket using your SSH keys, the command will produce output similar to:

```text
authenticated via ssh key.
You can use git to connect to Bitbucket. Shell access is disabled
```

### Install argocd

```text
kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deployment/argocd-server -n argocd
kubectl create secret generic bitbucket-ssh-key -n argocd --from-file=sshPrivateKey=$HOME/.ssh/argocd_bitbucket
ssh-keyscan -t rsa bitbucket.slalom.com > /tmp/known_hosts
export ARGOPASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Argocd Admin user password:\n ${ARGOPASS}"
```

- In new terminal shell run

```text
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Back to other shell - default user for Agrocd is "admin", copy password output from previous commmand:

```text
argocd login localhost:8080
argocd cluster add minikube --in-cluster
```

### Add Repo to Argo - replace git path with appropriate value

```text
argocd repo add [git@bitbucket.org:slalom-consulting/demo.git] --ssh-private-key-path $HOME/.ssh/argocd_bitbucket
```

## Deploy Base Apps

Deploy Istio and other base apps

```text
kubectl apply -f ./bootstrap/root-app.yaml
```

- Review status of istio and ensure all pods are running. NOTE - istio-gateway may need to be restarted is stuck in "pending"

```text
kubectl get pods -n istio-system
NAME                                    READY   STATUS    RESTARTS   AGE
istio-cni-node-8ffl6                    1/1     Running   0          2m7s
istio-ingressgateway-6876cbbff7-j5fx9   1/1     Running   0          30s
istiod-7695f67bd8-qdjv2                 1/1     Running   0          2m14s
```

## Add applications

### Team1 App

- Create and label namespace

```text
kubectl create ns team1 && \
kubectl label ns team1 istio-injection=enabled
```

```text
yq e '
  .metadata.name = "app1-team1" |
  .spec.destination.namespace = "team1" |
  .spec.source.helm.values = (.spec.source.helm.values | sub("HOSTNAME", "team1.k8slab.local"))
' ./argo-apps/app1/application.yaml | kubectl apply -f -
```

- Note the application in team1 namespace has the Istio container added

```text
kubectl get pods -n team1
NAME                            READY   STATUS    RESTARTS   AGE
customers-v1-667d457cb7-zz6tj   2/2     Running   0          20s
sleep-bd465dd68-zbmq7           2/2     Running   0          20s
web-frontend-5d8fdb5d86-qrm8k   2/2     Running   0          20s
```

### Team2 App

### Create a secure namespace for team2

```text
helm install secure-namespace-team2 ./manifests/secure-namespace \
  --set namespace=team2 \
  --create-namespace   
```

- Deploy app to secure namespace for team2

```text
yq e '
  .metadata.name = "app1-team2" |
  .spec.destination.namespace = "team2" |
  .spec.source.helm.values = (.spec.source.helm.values | sub("HOSTNAME", "team2.k8slab.local"))
' ./argo-apps/app1/application.yaml | kubectl apply -f -
```

- Note the application in team2 namespace has the Istio container added

```text
kubectl get pods -n team2                                         
NAME                            READY   STATUS    RESTARTS   AGE
customers-v1-667d457cb7-b2tvb   2/2     Running   0          19s
sleep-bd465dd68-2pmbq           2/2     Running   0          19s
web-frontend-75b7f755d7-bpspt   2/2     Running   0          19s
```

### Bad App is configured without secure settings

### Install bad-app for team1 - team1 namespace is not configured for security

```text
yq e '
  .metadata.name = "bad-app-team1" |
  .spec.destination.namespace = "team1" |
  .spec.source.helm.values = (.spec.source.helm.values | sub("HOSTNAME", "team1-bad.k8slab.local"))
' ./argo-apps/bad-app/application.yaml | kubectl apply -f -
```

- Note the application in team1 namespace is able to be deployed

### Install bad-app for team2 - team2 namespace IS configured for security

```text
yq e '
  .metadata.name = "bad-app-team2" |
  .spec.destination.namespace = "team2" |
  .spec.source.helm.values = (.spec.source.helm.values | sub("HOSTNAME", "team2-bad.k8slab.local"))
' ./argo-apps/bad-app/application.yaml | kubectl apply -f -
```

- Note the application in team2 namespace is NOT able to be deployed due to lack of security settings and resource values

## Review Deployment Status

### Note the status of the "bad" app

```text
kubectl get deployment customers2-v1 -n team2 -o json | jq  '.status'
{
  "conditions": [
    {
      "lastTransitionTime": "2025-07-02T16:15:10Z",
      "lastUpdateTime": "2025-07-02T16:15:10Z",
      "message": "Deployment does not have minimum availability.",
      "reason": "MinimumReplicasUnavailable",
      "status": "False",
      "type": "Available"
    },
    {
      "lastTransitionTime": "2025-07-02T16:15:10Z",
      "lastUpdateTime": "2025-07-02T16:15:10Z",
      "message": "pods \"customers2-v1-746bc98bf8-zrl27\" is forbidden: failed quota: team-quota: must specify limits.cpu for: svc; limits.memory for: svc; requests.cpu for: svc; requests.memory for: svc",
      "reason": "FailedCreate",
      "status": "True",
      "type": "ReplicaFailure"
    },
    {
      "lastTransitionTime": "2025-07-02T16:25:11Z",
      "lastUpdateTime": "2025-07-02T16:25:11Z",
      "message": "ReplicaSet \"customers2-v1-746bc98bf8\" has timed out progressing.",
      "reason": "ProgressDeadlineExceeded",
      "status": "False",
      "type": "Progressing"
    }
  ],
  "observedGeneration": 1,
  "unavailableReplicas": 1
}
```

- The namespace is configured to require resource requests/limits and requires securityContext settings as well. Without these a deployment will not deploy

- Run script to audit existing deployment against PSA restrict policy.

```text
./tools/audit-psa-compliance.sh team1 restricted
=== PSA Compliance Audit for namespace: team1 ===
Policy Level: restricted
=== Checking Deployments ===
Checking deployment/customers-v1...
Checking deployment/sleep...
Checking deployment/web-frontend...
=== Checking DaemonSets ===
=== Checking StatefulSets ===
=== Audit Results ===
Results saved to: psa-audit-20250724_111021/violations.csv
Total Resources Checked:        3
Compliant:        3
Non-Compliant:        1

=== Non-Compliant Resources ===
- deployment/web-frontend: run-as-root
```

## Add metallb and Observability Tools

```text
minikube addons enable metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml
kubectl rollout status deployment/controller -n metallb-system
kubectl apply -f ./manifests/metalLB/ip-pool.yaml

kubectl apply -f ./manifests/istio-addons
kubectl rollout status deployment/kiali -n istio-system
```

## Test "external" access

### prep hosts file

```test
sudo vi /etc/hosts
```

Add the appropriate hostname mapping to point to loopback/127.0.0.1:

```text
cat /etc/hosts
```

Should return something like:

```text
##
# Host Database
#
# localhost is used to configure the loopback interface
# when the system is booting.  Do not change this entry.
##
127.0.0.1       localhost
255.255.255.255 broadcasthost
::1             localhost
127.0.0.1       team1.k8slab.local
127.0.0.1       team2.k8slab.local
```

- In a yet another shell run - when promted enter local password for sudo access

```text
minikube tunnel
```

- Open new shell and run:

```text
istioctl dashboard kiali
```

## Kiali Dashboard

- Select the Traffic Graph tab
- Select team1 and team2 from Namespace dropdown

## Create traffic from local to K8s applications

- From a new local shell create external traffic to team1 app by running curl

```while true; do curl -I http://team1.k8slab.local; sleep 3; done```

- From a new local shell create external traffic to team2 by running curl

```while true; do curl -I http://team2.k8slab.local; sleep 3; done```

### Note the lock icon which indicates mTLS

### Note the traffic is flowing through Istio-ingressgateway with host-based routing

![Kiali Service Graph](images/screenshots/kiali-graph-setup.png)

## Troushooting

### Check proxy routes

```text
istioctl proxy-config routes $(kubectl get pods -l istio=ingressgateway -n istio-system -o name) -n istio-system

NAME        VHOST NAME              DOMAINS              MATCH                  VIRTUAL SERVICE
http.80     team1.k8slab.local:80   team1.k8slab.local   /*                     web-frontend.team1
http.80     team2.k8slab.local:80   team2.k8slab.local   /*                     web-frontend.team2
            backend                 *                    /healthz/ready*        
            backend                 *                    /stats/prometheus*    
```

## Traffic Management

- Create new pod in default namespace and test access to app1/app2

```text
kubectl run curl-loop --image=curlimages/curl --restart=Never -it --rm -- sh -c 'while true; do curl -I http://web-frontend.team2.svc.cluster.local; sleep 3; done'

```

- Note curl is successfull accross namespace (from default to team2)

```text
TTP/1.1 200 OK
x-powered-by: Express
content-type: text/html; charset=utf-8
content-length: 2471
etag: W/"9a7-hEXE7lJW5CDgD+e2FypGgChcgho"
date: Wed, 02 Jul 2025 19:25:37 GMT
x-envoy-upstream-service-time: 2571
server: istio-envoy
connection: close
x-envoy-decorator-operation: web-frontend.team1.svc.cluster.local:80/*
```

- Add STRICT PeerAuth Policy

```text
kubectl apply -f ./manifests/mtls/strict.yaml
```

- Note traffic is dropped from outside the mesh:

```text
curl: (56) Recv failure: Connection reset by peer
curl: (56) Recv failure: Connection reset by peer
curl: (56) Recv failure: Connection reset by peer
```

- Connect to pod in team1 and curl to team2

```text
kubectl exec -it $(kubectl get pods -l app=sleep -n team1 -o name) -n team1 -- curl -I customers.team2
```

- Note curl is successfull from across namespace within mesh

```text
kubectl exec -it $(kubectl get pods -l app=sleep -n team1 -o name) -n team1 -- sh -c 'while true; do curl -I customers.team2; sleep 3; done'

HTTP/1.1 200 OK
content-type: application/json
date: Wed, 02 Jul 2025 19:47:01 GMT
content-length: 274
x-envoy-upstream-service-time: 7
server: envoy
```

## Authorization Policy

- Apply Istio Authorization policy to limit access to customer serive to only web-frontend Service Account

```text
kubectl apply -f ./manifests/istio-policies/manifests/customer-auth.yaml
```

- Note curl from team2 sleep pod to team1 customers pod is "Fordidden":

```text
kubectl exec -it $(kubectl get pods -l app=sleep -n team2 -o name) -n team2 -- sh -c 'while true; do curl -I customers.team1; sleep 3; done'
HTTP/1.1 403 Forbidden
content-length: 19
content-type: text/plain
date: Mon, 14 Jul 2025 12:33:56 GMT
server: envoy
x-envoy-upstream-service-time: 2
```

- Apply policy to limit access to the web-frontend service and note the curl is blocked after applying policy

```text
kubectl apply -f ./manifests/istio-policies/manifests/web-auth.yaml


    kubectl exec -it $(kubectl get pods -l app=sleep -n team2 -o name) -n team2 -- sh -c 'while true; do curl -I web-frontend.team1; sleep 3; done'

    HTTP/1.1 503 Service Unavailable
    content-length: 95
    content-type: text/plain
    date: Mon, 14 Jul 2025 12:41:44 GMT
    server: envoy
    x-envoy-upstream-service-time: 1108
```

## Default Authorization Policies

- Apply default Istio Authorization Policies via Helm

```text
helm install istio-policies ./manifests/istio-policies --namespace team1 --set namespace=team1
NAME: istio-policies
LAST DEPLOYED: Mon Jul 14 09:34:55 2025
NAMESPACE: team1
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

## Outbound traffic

- Create a curl to external host (google.com) and note the traffic "passthroughCluster"

```text
kubectl exec -it $(kubectl get pods -l app=sleep -n team1 -o name) -n team1 -- sh -c 'while true; do curl -I https://www.google.com; sleep 3; done'
```

![Without-ServiceEntry][without-service-entry]

- Add ServiceEntry and note the traffic now is within the mesh

```text
kubectl apply -f ./manifests/istio-policies/manifests/google-service-entry.yaml -n team1

serviceentry.networking.istio.io/google-external created
```

![With-ServiceEntry](images/screenshots/with-service-entry.png)

### Traffic within mesh

![Kiali Service Graph](images/screenshots/withinmesh.png)

## Security Policies

## Apply Gatekeeper ContraintTemplates and Constraints, Create New Secure Namespace

```text
kubectl apply -f ./manifests/gatekeeper-policies/templates
kubectl apply -f ./manifests/gatekeeper-policies/constraints
helm install secure-namespace ./manifests/secure-namespace \
  --set namespace=team3 \
  --namespace team3 \
  --create-namespace
```

## Test Constraints with "Bad" App

- Review yaml for app - `cat ./manifests/sample-apps/bad.yaml`
- Update image value to remove the docker.io path and set to `nginx`
- Test yaml and see results - Note the Error on the allow-registries

```text
kubectl apply --dry-run=server -f ./manifests/sample-apps/bad.yaml -n team3
Error from server (Forbidden): error when creating "./manifests/sample-apps/bad.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [allowed-registries] Deployment/sec-test-deployment container <nginx> uses image without registry: nginx
```

- Add path back and test

```text
kubectl apply --dry-run=server -f ./manifests/sample-apps/bad.yaml -n team3
deployment.apps/sec-test-deployment created (server dry run)
```

- Set privileged to true and test

```text
kubectl apply --dry-run=server -f ./manifests/sample-apps/bad.yaml -n team3
The Deployment "sec-test-deployment" is invalid: spec.template.spec.containers[0].securityContext: Invalid value: core.SecurityContext{Capabilities:(*core.Capabilities)(0x4020c89b00), Privileged:(*bool)(0x401647c660), SELinuxOptions:(*core.SELinuxOptions)(nil), WindowsOptions:(*core.WindowsSecurityContextOptions)(nil), RunAsUser:(*int64)(nil), RunAsGroup:(*int64)(nil), RunAsNonRoot:(*bool)(0x401647c661), ReadOnlyRootFilesystem:(*bool)(nil), AllowPrivilegeEscalation:(*bool)(0x401647c65c), ProcMount:(*core.ProcMountType)(nil), SeccompProfile:(*core.SeccompProfile)(0x401e9f2288), AppArmorProfile:(*core.AppArmorProfile)(nil)}: cannot set `allowPrivilegeEscalation` to false and `privileged` to true
```

- Rollback privileged to false and set seccompProfile to Unconfined - NOTE: Warning will not prevent deployment but Error will

```text
k8s-secure-cluster % kubectl apply --dry-run=server -f ./manifests/sample-apps/bad.yaml -n team3
Warning: would violate PodSecurity "restricted:latest": seccompProfile (container "nginx" must not set securityContext.seccompProfile.type to "Unconfined")
Error from server (Forbidden): error when creating "./manifests/sample-apps/bad.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [require-seccomp-profile] Deployment/sec-test-deployment container <nginx> has disallowed seccompProfile: Unconfined
```

- Rollback seccompProfile to RuntimeDefault and comment out the readinessProbe section and test

```text
        #readinessProbe:
        #  httpGet:
        #    path: /
        #    port: 8080
        #  initialDelaySeconds: 5
        #  periodSeconds: 10
        #  failureThreshold: 3



kubectl apply --dry-run=server -f ./manifests/sample-apps/bad.yaml -n team3
Error from server (Forbidden): error when creating "./manifests/sample-apps/bad.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [enforce-readiness-liveness] Container <nginx> is missing required <readinessProbe>
```

- Rollback readinessProbe changes and comment out the livenessProbe section and test

```text
kubectl apply --dry-run=server -f ./manifests/sample-apps/bad.yaml -n team3
Error from server (Forbidden): error when creating "./manifests/sample-apps/bad.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [enforce-readiness-liveness] Container <nginx> is missing required <livenessProbe>
```

## CLEAN UP

```minikube delete```

```colima stop```

- Close/terminate shells running the ```port-forward``` and ```minikube tunnel``` commands

[without-service-entry]: images/screenshots/without-service-entry.png