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


kubectl apply -f 000-etcdcluster.yaml
kubectl apply -f 001-deploy-certs.yaml

kubectl get pod,certificate,issuer,secret -n cluster

helm template ./002.paas-kubernetes-chart-separated.5 > 002.paas-kubernetes-chart-separated.5.yaml
kubectl apply -f 002.paas-kubernetes-chart-separated.5.yaml

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




cat <<EOF>0010-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kubeadm:bootstrap-signer-clusterinfo
  namespace: kube-public
subjects:
- kind: Group
  name: system:unauthenticated
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: kubeadm:bootstrap-signer-clusterinfo
  apiGroup: rbac.authorization.k8s.io
EOF
kubectl --kubeconfig ./config apply -f ./0010-rbac.yaml
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


kubectl --kubeconfig ./config apply -f 005-RBAC-konnectivity-server.yaml
kubectl --kubeconfig ./config apply -f 006-deploy-konnectivity-agent.yaml


kubectl --kubeconfig ./config get node,pod,svc -A


kubeadm token create --kubeconfig ./config --print-join-command --ttl=24h
>>> kubeadm join 12.0.100.97:6443 --token vrtvfx.sqdbcmb1t3pw2z9j --discovery-token-ca-cert-hash sha256:ea58da28707218a79b6ecfab344f1db01fd5726560a3f80a8b2176649161b8d5



root@node130:~/paas-kubernetes-chart-separated.deploy.4# kubectl --kubeconfig ./config get node,pod,svc -A -o wide
NAME           STATUS   ROLES    AGE     VERSION   INTERNAL-IP       EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                CONTAINER-RUNTIME
node/node142   Ready    <none>   2m14s   v1.36.1   192.168.200.142   <none>        Debian GNU/Linux 13 (trixie)   6.12.88+deb13-amd64 (amd64)   containerd://2.3.0
node/node143   Ready    <none>   2m17s   v1.36.1   192.168.200.143   <none>        Debian GNU/Linux 13 (trixie)   6.12.88+deb13-amd64 (amd64)   containerd://2.3.0

NAMESPACE     NAME                                           READY   STATUS    RESTARTS   AGE     IP                NODE      NOMINATED NODE   READINESS GATES
default       pod/ekvm-busybox-deployment-5b5b448889-5jdk2   1/1     Running   0          71s     244.2.0.9         node143   <none>           <none>
default       pod/ekvm-busybox-deployment-5b5b448889-9p4zh   1/1     Running   0          71s     244.2.0.30        node143   <none>           <none>
default       pod/ekvm-busybox-deployment-5b5b448889-bm5dt   1/1     Running   0          71s     244.2.1.227       node142   <none>           <none>
default       pod/ekvm-busybox-deployment-5b5b448889-pk2hb   1/1     Running   0          71s     244.2.1.248       node142   <none>           <none>
default       pod/nginx-deployment-v1-68d8c6c7bb-bwdbf       1/1     Running   0          72s     244.2.1.7         node142   <none>           <none>
default       pod/nginx-deployment-v2-76548cb578-f2zhl       1/1     Running   0          72s     244.2.1.90        node142   <none>           <none>
default       pod/nginx-deployment-v3-54698fb7-8hvf6         1/1     Running   0          72s     244.2.1.131       node142   <none>           <none>
default       pod/nginx-deployment-v4-76f75c5b75-qmcp6       1/1     Running   0          72s     244.2.0.230       node143   <none>           <none>
default       pod/nginx-deployment-v5-f7f5d966c-fvtwc        1/1     Running   0          72s     244.2.0.133       node143   <none>           <none>
default       pod/postgres13-5c7695bcf5-hglzr                1/1     Running   0          71s     244.2.1.245       node142   <none>           <none>
kube-system   pod/cilium-89tv4                               1/1     Running   0          2m17s   192.168.200.143   node143   <none>           <none>
kube-system   pod/cilium-bvv9f                               1/1     Running   0          2m14s   192.168.200.142   node142   <none>           <none>
kube-system   pod/cilium-envoy-2q2d4                         1/1     Running   0          2m17s   192.168.200.143   node143   <none>           <none>
kube-system   pod/cilium-envoy-xflqp                         1/1     Running   0          2m14s   192.168.200.142   node142   <none>           <none>
kube-system   pod/cilium-operator-5fb755fc8b-2rc82           1/1     Running   0          3m24s   192.168.200.143   node143   <none>           <none>
kube-system   pod/cilium-operator-5fb755fc8b-49zvk           1/1     Running   0          3m24s   192.168.200.142   node142   <none>           <none>
kube-system   pod/coredns-5d44d58b58-9hn92                   1/1     Running   0          5m36s   244.2.1.83        node142   <none>           <none>
kube-system   pod/coredns-5d44d58b58-qwqcs                   1/1     Running   0          5m36s   244.2.0.40        node143   <none>           <none>
kube-system   pod/coredns-5d44d58b58-zgd6l                   1/1     Running   0          5m36s   244.2.0.22        node143   <none>           <none>
kube-system   pod/konnectivity-agent-p7rhd                   1/1     Running   0          7s      244.2.1.81        node142   <none>           <none>
kube-system   pod/konnectivity-agent-z2slk                   1/1     Running   0          7s      244.2.0.81        node143   <none>           <none>

NAMESPACE     NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE     SELECTOR
default       service/ekvm-busybox   LoadBalancer   244.1.169.237   <pending>     1022:31040/TCP   71s     app=ekvm
default       service/kubernetes     ClusterIP      244.1.0.1       <none>        443/TCP          8m54s   <none>
default       service/nginx-v1       LoadBalancer   244.1.170.33    <pending>     8080:32004/TCP   72s     app=nginx-v1
default       service/nginx-v2       LoadBalancer   244.1.249.177   <pending>     8080:30900/TCP   72s     app=nginx-v2
default       service/nginx-v3       LoadBalancer   244.1.190.156   <pending>     8080:30579/TCP   72s     app=nginx-v3
default       service/nginx-v4       LoadBalancer   244.1.124.62    <pending>     8080:30153/TCP   72s     app=nginx-v4
default       service/nginx-v5       LoadBalancer   244.1.141.249   <pending>     8080:31389/TCP   72s     app=nginx-v5
default       service/postgres13     LoadBalancer   244.1.16.23     <pending>     5432:30319/TCP   72s     app=postgres13
kube-system   service/cilium-envoy   ClusterIP      None            <none>        9964/TCP         3m24s   k8s-app=cilium-envoy
kube-system   service/coredns        ClusterIP      244.1.4.91      <none>        53/UDP,53/TCP    5m36s   app.kubernetes.io/instance=coredns,app.kubernetes.io/name=coredns,k8s-app=coredns
kube-system   service/hubble-peer    ClusterIP      244.1.106.67    <none>        443/TCP          3m24s   k8s-app=cilium
root@node130:~/paas-kubernetes-chart-separated.deploy.4#


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
