```

#
# controlPlaneEndpoint: 12.0.100.97:6443
# podSubnet: 244.2.0.0/16
# serviceSubnet: 244.1.0.0/16
#

apt install git -y
git clone https://github.com/aenix-io/etcd-operator


cat <<EOF>/root/etcd-operator/charts/etcd-operator/Chart.yaml
apiVersion: v2
name: etcd-operator
type: application
version: 0.4.3 # Placeholder, the actual version will be set in the release pipeline.
appVersion: "v0.4.3" # Placeholder, the actual version will be set in the release pipeline.
EOF
cd /root/etcd-operator/charts
kubectl create ns etcd-operator
helm install etcd-operator -n etcd-operator \
  --set etcdOperator.vpa.enabled=false \
  --set kubeRbacProxy.vpa.enabled=false \
  --set replicaCount=1 etcd-operator \
  --set etcdOperator.image.repository=ghcr.io/aenix-io/etcd-operator \
  --set etcdOperator.image.tag=v0.4.3 \
  --set kubeRbacProxy.image.repository=quay.io/brancz/kube-rbac-proxy \
  --set kubeRbacProxy.image.tag=v0.21.2
kubectl get all -n etcd-operator


kubectl create ns cluster
kubectl create configmap tenant-audit-policy --from-file=/etc/kubernetes/policies/audit-policy.yaml -n cluster


helm install -n cluster --set stage001=true cluster-stage001 ./002.paas-kubernetes-chart-separated.7
helm install -n cluster --set stage002=true cluster-stage002 ./002.paas-kubernetes-chart-separated.7

kubectl get pod,certificate,issuer,secret -n cluster

# helm template --set stage003=true ./002.paas-kubernetes-chart-separated.6

helm install -n cluster --set stage003=true cluster-stage003 ./002.paas-kubernetes-chart-separated.7

helm install -n cluster --set stage005=true cluster-stage005 ./002.paas-kubernetes-chart-separated.7

kubectl get secret paas-one-admin-config -n cluster -o jsonpath='{.data.config}' | base64 -d > config
helm upgrade --install --kubeconfig ./config -n kube-system --set stage010=true cluster-stage010 ./002.paas-kubernetes-chart-separated.7

kubectl --kubeconfig ./config get node,pod,svc -A

############################################################################################
############################################################################################
############################################################################################


### helm repo add coredns https://coredns.github.io/helm
### helm pull coredns/coredns
### helm --namespace=kube-system install coredns coredns/coredns
### helm --kubeconfig ./config --namespace=kube-system install coredns coredns/coredns --set replicaCount=3
### 
### helm install cilium oci://quay.io/cilium/charts/cilium \
###   --version 1.19.3 \
###   --namespace kube-system \
###   --kubeconfig ./config \
###   --set kubeProxyReplacement=true \
###   --set k8sServiceHost=12.0.100.97 \
###   --set ipam.operator.clusterPoolIPv4PodCIDRList="244.2.0.0/16" \
###   --set ipam.operator.clusterPoolIPv4MaskSize="24" \
###   --set k8sServicePort=6443
### 
### 
### helm upgrade cilium oci://quay.io/cilium/charts/cilium \
###   --version 1.19.3 \
###   --namespace kube-system \
###   --kubeconfig ./config \
###   --set kubeProxyReplacement=true \
###   --set k8sServiceHost=12.0.100.97 \
###   --set k8sServicePort=6443 \
###   --reuse-values
### 



############################################################################################
############################################################################################
############################################################################################

root@node130:~/paas-kubernetes-chart-separated.deploy.6# kubectl --kubeconfig ./config get node,pod,svc -A -o wide
NAME           STATUS   ROLES    AGE   VERSION   INTERNAL-IP       EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                CONTAINER-RUNTIME
node/node142   Ready    <none>   74m   v1.36.1   192.168.200.142   <none>        Debian GNU/Linux 13 (trixie)   6.12.88+deb13-amd64 (amd64)   containerd://2.3.0
node/node143   Ready    <none>   75m   v1.36.1   192.168.200.143   <none>        Debian GNU/Linux 13 (trixie)   6.12.88+deb13-amd64 (amd64)   containerd://2.3.0

NAMESPACE     NAME                                           READY   STATUS    RESTARTS   AGE   IP                NODE      NOMINATED NODE   READINESS GATES
default       pod/ekvm-busybox-deployment-5b5b448889-5r2d4   1/1     Running   0          68m   244.2.1.129       node142   <none>           <none>
default       pod/ekvm-busybox-deployment-5b5b448889-ghnfg   1/1     Running   0          68m   244.2.0.24        node143   <none>           <none>
default       pod/ekvm-busybox-deployment-5b5b448889-nl7pz   1/1     Running   0          68m   244.2.0.132       node143   <none>           <none>
default       pod/ekvm-busybox-deployment-5b5b448889-spwpn   1/1     Running   0          68m   244.2.1.61        node142   <none>           <none>
default       pod/nginx-deployment-v1-68d8c6c7bb-bjsfn       1/1     Running   0          68m   244.2.1.217       node142   <none>           <none>
default       pod/nginx-deployment-v2-76548cb578-924z6       1/1     Running   0          68m   244.2.1.150       node142   <none>           <none>
default       pod/nginx-deployment-v3-54698fb7-bh4k2         1/1     Running   0          68m   244.2.0.166       node143   <none>           <none>
default       pod/nginx-deployment-v4-76f75c5b75-kbksm       1/1     Running   0          68m   244.2.0.58        node143   <none>           <none>
default       pod/nginx-deployment-v5-f7f5d966c-ltbg2        1/1     Running   0          68m   244.2.1.197       node142   <none>           <none>
default       pod/postgres13-5c7695bcf5-gnrrl                1/1     Running   0          68m   244.2.1.135       node142   <none>           <none>
kube-system   pod/cilium-2zvq8                               1/1     Running   0          74m   192.168.200.142   node142   <none>           <none>
kube-system   pod/cilium-envoy-bqm5p                         1/1     Running   0          74m   192.168.200.142   node142   <none>           <none>
kube-system   pod/cilium-envoy-txvz8                         1/1     Running   0          75m   192.168.200.143   node143   <none>           <none>
kube-system   pod/cilium-operator-5fb755fc8b-6qh57           1/1     Running   0          76m   192.168.200.143   node143   <none>           <none>
kube-system   pod/cilium-operator-5fb755fc8b-q25s9           1/1     Running   0          76m   192.168.200.142   node142   <none>           <none>
kube-system   pod/cilium-zg8fq                               1/1     Running   0          75m   192.168.200.143   node143   <none>           <none>
kube-system   pod/coredns-5d44d58b58-pl6z4                   1/1     Running   0          76m   244.2.0.176       node143   <none>           <none>
kube-system   pod/coredns-5d44d58b58-rsfsb                   1/1     Running   0          76m   244.2.0.142       node143   <none>           <none>
kube-system   pod/coredns-5d44d58b58-tdzp4                   1/1     Running   0          76m   244.2.0.219       node143   <none>           <none>
kube-system   pod/konnectivity-agent-87mfb                   1/1     Running   0          36s   244.2.0.108       node143   <none>           <none>
kube-system   pod/konnectivity-agent-hc2nk                   1/1     Running   0          36s   244.2.1.243       node142   <none>           <none>

NAMESPACE     NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
default       service/ekvm-busybox   LoadBalancer   244.1.139.186   <pending>     1022:30151/TCP   68m   app=ekvm
default       service/kubernetes     ClusterIP      244.1.0.1       <none>        443/TCP          78m   <none>
default       service/nginx-v1       LoadBalancer   244.1.30.125    <pending>     8080:31426/TCP   68m   app=nginx-v1
default       service/nginx-v2       LoadBalancer   244.1.236.134   <pending>     8080:30926/TCP   68m   app=nginx-v2
default       service/nginx-v3       LoadBalancer   244.1.181.100   <pending>     8080:30987/TCP   68m   app=nginx-v3
default       service/nginx-v4       LoadBalancer   244.1.151.199   <pending>     8080:30606/TCP   68m   app=nginx-v4
default       service/nginx-v5       LoadBalancer   244.1.145.240   <pending>     8080:31427/TCP   68m   app=nginx-v5
default       service/postgres13     LoadBalancer   244.1.236.89    <pending>     5432:30364/TCP   68m   app=postgres13
kube-system   service/cilium-envoy   ClusterIP      None            <none>        9964/TCP         76m   k8s-app=cilium-envoy
kube-system   service/coredns        ClusterIP      244.1.142.97    <none>        53/UDP,53/TCP    76m   app.kubernetes.io/instance=coredns,app.kubernetes.io/name=coredns,k8s-app=coredns
kube-system   service/hubble-peer    ClusterIP      244.1.217.151   <none>        443/TCP          76m   k8s-app=cilium
root@node130:~/paas-kubernetes-chart-separated.deploy.6#




# kubectl --kubeconfig ./config get secret bootstrap-token-tjtupk -n kube-system -o yaml
#
#
# kubectl drain node143 --delete-emptydir-data  --ignore-daemonsets
# kubectl delete node node143
#
# https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/admin/konnectivity/konnectivity-rbac.yaml
# https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/admin/konnectivity/konnectivity-agent.yaml
# 
#
# registry.k8s.io/kas-network-proxy/proxy-server                           v0.34.0
# 
#         image: registry.k8s.io/kas-network-proxy/proxy-agent
#         version: v0.34.0
#         image: registry.k8s.io/kas-network-proxy/proxy-server
#         version: v0.34.0
# 		
# curl https://europe-north1-docker.pkg.dev/v2/k8s-artifacts-prod/images/kas-network-proxy/proxy-agent/tags/list | jq .tags
#
```
