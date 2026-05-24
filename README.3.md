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


# helm template --set stage001=true ./002.paas-kubernetes-chart-separated.6
# helm template --set stage002=true ./002.paas-kubernetes-chart-separated.6

helm install -n cluster --set stage001=true cluster-stage001 ./002.paas-kubernetes-chart-separated.6
helm install -n cluster --set stage002=true cluster-stage002 ./002.paas-kubernetes-chart-separated.6


kubectl get pod,certificate,issuer,secret -n cluster

# helm template --set stage003=true ./002.paas-kubernetes-chart-separated.6

helm install -n cluster --set stage003=true cluster-stage003 ./002.paas-kubernetes-chart-separated.6



kubectl get pod,svc,cm -n cluster

kubectl get -n cluster secret/paas-one-pki-admin-client -o json > k8s-ca.json

cat <<EOF>config
clusters:
- cluster:
    certificate-authority-data: `cat k8s-ca.json  | jq -r '.data."ca.crt"'`
    server: https://12.0.100.97:6443
  name: cluster.local
contexts:
- context:
    cluster: cluster.local
    user: kubernetes-admin
  name: kubernetes-admin@cluster.local
current-context: kubernetes-admin@cluster.local
kind: Config
users:
- name: kubernetes-admin
  user:
    client-certificate-data: `cat k8s-ca.json  | jq -r '.data."tls.crt"'`
    client-key-data: `cat k8s-ca.json  | jq -r '.data."tls.key"'`
EOF


kubectl --kubeconfig=./config  get node,all,cm -A


cat <<EOF>k8s-kubeadm.yaml
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
controlPlaneEndpoint: 12.0.100.97:6443
networking:
  dnsDomain: cluster.local
  podSubnet: 244.2.0.0/16
  serviceSubnet: 244.1.0.0/16
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
allowedUnsafeSysctls:
- net.core.somaxconn
authentication:
    anonymous:
        enabled: false
    webhook:
        cacheTTL: 0s
        enabled: true
authorization:
    mode: Webhook
    webhook:
        cacheAuthorizedTTL: 0s
        cacheUnauthorizedTTL: 0s
cgroupDriver: systemd
cgroupRoot: /
cgroupsPerQOS: true
clusterDomain: cluster.local
containerLogMaxFiles: 5
containerLogMaxSize: 50Mi
cpuManagerReconcilePeriod: 0s
evictionHard:
    imagefs.available: 25%
    imagefs.inodesFree: 15%
    memory.available: 500Mi
    nodefs.available: 20%
    nodefs.inodesFree: 10%
evictionMaxPodGracePeriod: 300
evictionMinimumReclaim:
    imagefs.available: 2Gi
    memory.available: 0Mi
    nodefs.available: 500Mi
evictionPressureTransitionPeriod: 5m
evictionSoft:
    imagefs.available: 30%
    imagefs.inodesFree: 25%
    memory.available: 500Mi
    nodefs.available: 25%
    nodefs.inodesFree: 15%
evictionSoftGracePeriod:
    imagefs.available: 2m30s
    imagefs.inodesFree: 2m30s
    memory.available: 2m30s
    nodefs.available: 2m30s
    nodefs.inodesFree: 2m30s
fileCheckFrequency: 0s
hairpinMode: hairpin-veth
healthzBindAddress: 127.0.0.1
httpCheckFrequency: 0s
imageGCHighThresholdPercent: 55
imageGCLowThresholdPercent: 50
imageMinimumGCAge: 0s
kubeAPIBurst: 100
kubeAPIQPS: 50
kubeReserved:
    cpu: 500m
    ephemeral-storage: 3Gi
    memory: 500Mi
kubeReservedCgroup: /kubelet.slice
kubeletCgroups: /kubelet.slice
logging:
    flushFrequency: 0
    options:
        json:
            infoBufferSize: 0
    verbosity: 0
maxOpenFiles: 1000000
maxParallelImagePulls: 5
maxPods: 20
memorySwap: {}
memoryThrottlingFactor: 0.9
nodeStatusMaxImages: 50
nodeStatusReportFrequency: 20s
nodeStatusUpdateFrequency: 30s
podPidsLimit: 4096
podsPerCore: 5
registerNode: true
resolvConf: /run/systemd/resolve/resolv.conf
rotateCertificates: true
runtimeRequestTimeout: 0s
serializeImagePulls: false
serverTLSBootstrap: false
shutdownGracePeriod: 15s
shutdownGracePeriodCriticalPods: 5s
streamingConnectionIdleTimeout: 0s
syncFrequency: 0s
systemReserved:
    cpu: 500m
    ephemeral-storage: 1Gi
    memory: 1000Mi
tlsCipherSuites:
- TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
- TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
- TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
- TLS_RSA_WITH_AES_256_GCM_SHA384
- TLS_RSA_WITH_AES_128_GCM_SHA256
- TLS_AES_128_GCM_SHA256
- TLS_AES_256_GCM_SHA384
- TLS_CHACHA20_POLY1305_SHA256
tlsMinVersion: VersionTLS13
volumeStatsAggPeriod: 0s
EOF


kubeadm init phase upload-config kubeadm --kubeconfig=./config --config ./k8s-kubeadm.yaml

kubeadm init phase upload-config kubelet --kubeconfig=./config --config ./k8s-kubeadm.yaml
kubectl --kubeconfig=./config  get node,all,cm -A


kubeadm init phase bootstrap-token --kubeconfig=./config --config ./k8s-kubeadm.yaml --skip-token-print 

#kubeadm init phase addon kube-proxy  --kubeconfig ./config --config ./k8s-kubeadm.yaml



kubectl --kubeconfig=./config get -n kube-public   configmap/cluster-info -o yaml
kubectl --kubeconfig=./config  config view --flatten
kubectl --kubeconfig=./config  get node,all,cm -A


helm repo add coredns https://coredns.github.io/helm
helm pull coredns/coredns
helm --namespace=kube-system install coredns coredns/coredns
helm --kubeconfig ./config --namespace=kube-system install coredns coredns/coredns --set replicaCount=3

kubectl --kubeconfig ./config get role kubeadm:bootstrap-signer-clusterinfo -n kube-public


kubeadm init phase bootstrap-token --kubeconfig ./config





helm install cilium oci://quay.io/cilium/charts/cilium \
  --version 1.19.3 \
  --namespace kube-system \
  --kubeconfig ./config \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=12.0.100.97 \
  --set ipam.operator.clusterPoolIPv4PodCIDRList="244.2.0.0/16" \
  --set ipam.operator.clusterPoolIPv4MaskSize="24" \
  --set k8sServicePort=6443


helm upgrade cilium oci://quay.io/cilium/charts/cilium \
  --version 1.19.3 \
  --namespace kube-system \
  --kubeconfig ./config \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=12.0.100.97 \
  --set k8sServicePort=6443 \
  --reuse-values



helm template --kubeconfig ./config --set stage010=true ./002.paas-kubernetes-chart-separated.6



kubectl --kubeconfig ./config get node,pod,svc -A


kubeadm token create --kubeconfig ./config --print-join-command --ttl=24h
>>> kubeadm join 12.0.100.97:6443 --token vrtvfx.sqdbcmb1t3pw2z9j --discovery-token-ca-cert-hash sha256:ea58da28707218a79b6ecfab344f1db01fd5726560a3f80a8b2176649161b8d5



root@node130:~/paas-kubernetes-chart-separated.deploy.5# kubectl --kubeconfig ./config get node,pod,svc -A
NAME           STATUS   ROLES    AGE     VERSION
node/node142   Ready    <none>   4m13s   v1.36.1
node/node143   Ready    <none>   4m15s   v1.36.1

NAMESPACE     NAME                                           READY   STATUS    RESTARTS   AGE
default       pod/ekvm-busybox-deployment-5b5b448889-bd5lk   1/1     Running   0          2m16s
default       pod/ekvm-busybox-deployment-5b5b448889-bft5r   1/1     Running   0          2m16s
default       pod/ekvm-busybox-deployment-5b5b448889-nglwc   1/1     Running   0          2m16s
default       pod/ekvm-busybox-deployment-5b5b448889-twb8j   1/1     Running   0          2m16s
default       pod/nginx-deployment-v1-68d8c6c7bb-j9625       1/1     Running   0          2m16s
default       pod/nginx-deployment-v2-76548cb578-d8skt       1/1     Running   0          2m16s
default       pod/nginx-deployment-v3-54698fb7-8llnw         1/1     Running   0          2m16s
default       pod/nginx-deployment-v4-76f75c5b75-2mxwc       1/1     Running   0          2m16s
default       pod/nginx-deployment-v5-f7f5d966c-njmf2        1/1     Running   0          2m16s
default       pod/postgres13-5c7695bcf5-j589p                1/1     Running   0          2m16s
kube-system   pod/cilium-c2hdj                               1/1     Running   0          4m15s
kube-system   pod/cilium-envoy-hhx6b                         1/1     Running   0          4m15s
kube-system   pod/cilium-envoy-w8qgh                         1/1     Running   0          4m13s
kube-system   pod/cilium-operator-5fb755fc8b-l6b9p           1/1     Running   0          4m44s
kube-system   pod/cilium-operator-5fb755fc8b-lfq8k           1/1     Running   0          4m44s
kube-system   pod/cilium-x2ttf                               1/1     Running   0          4m13s
kube-system   pod/coredns-5d44d58b58-6mph9                   1/1     Running   0          5m
kube-system   pod/coredns-5d44d58b58-79w7s                   1/1     Running   0          5m
kube-system   pod/coredns-5d44d58b58-f4d2b                   1/1     Running   0          5m

NAMESPACE     NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
default       service/ekvm-busybox   LoadBalancer   244.1.159.10    <pending>     1022:31955/TCP   2m16s
default       service/kubernetes     ClusterIP      244.1.0.1       <none>        443/TCP          6m5s
default       service/nginx-v1       LoadBalancer   244.1.197.71    <pending>     8080:31504/TCP   2m16s
default       service/nginx-v2       LoadBalancer   244.1.235.55    <pending>     8080:32259/TCP   2m16s
default       service/nginx-v3       LoadBalancer   244.1.208.166   <pending>     8080:31459/TCP   2m16s
default       service/nginx-v4       LoadBalancer   244.1.75.29     <pending>     8080:32116/TCP   2m16s
default       service/nginx-v5       LoadBalancer   244.1.246.138   <pending>     8080:32199/TCP   2m16s
default       service/postgres13     LoadBalancer   244.1.57.108    <pending>     5432:32148/TCP   2m16s
kube-system   service/cilium-envoy   ClusterIP      None            <none>        9964/TCP         4m44s
kube-system   service/coredns        ClusterIP      244.1.223.226   <none>        53/UDP,53/TCP    5m
kube-system   service/hubble-peer    ClusterIP      244.1.163.241   <none>        443/TCP          4m44s
root@node130:~/paas-kubernetes-chart-separated.deploy.5#


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
