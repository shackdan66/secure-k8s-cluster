### Initial Development On Minikube with Colima on MacOs
colima start --memory 8 --cpu 8
docker context use colima
minikube start --driver=docker --memory=8192 --cpus=4 --force



k create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

 # Login to ArgoCD and register repo
 kubectl port-forward svc/argocd-server -n argocd 8080:443
 argocd login localhost:8080
 argocd cluster add minikube --in-cluster

- Add repo using the secret instead of file path
- Create secret with SSH private key
kubectl create secret generic github-ssh-key --from-file=sshPrivateKey=$HOME/.ssh/argocd_rsa -n argocd

# Add repository using the secret
argocd repo add git@github.com:shackdan/minikube.git --ssh-private-key-path ~/.ssh/argocd_rsa

###
CLEAN UP
Delete the argo
kubectl get applications.argoproj.io -n argocd -o name | xargs -n1 kubectl delete -n argocd

