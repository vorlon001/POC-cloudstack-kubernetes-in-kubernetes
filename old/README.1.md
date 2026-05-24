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
kubeadm init phase upload-config kubeadm --kubeconfig=/root/paas-kubernetes-chart-separated.deploy.3/config --config ./k8s-kubeadm.yaml
kubeadm init phase upload-config kubelet --kubeconfig=/root/paas-kubernetes-chart-separated.deploy.3/config --config ./k8s-kubeadm.yaml
kubectl --kubeconfig=./config  get node,all,cm -A


kubeadm init phase bootstrap-token --kubeconfig=/root/paas-kubernetes-chart-separated.deploy.3/config --config ./k8s-kubeadm.yaml --skip-token-print 

#kubeadm init phase addon kube-proxy  --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config --config ./k8s-kubeadm.yaml



kubectl --kubeconfig=/root/paas-kubernetes-chart-separated.deploy.3/config get -n kube-public   configmap/cluster-info -o yaml
kubectl --kubeconfig=./config  config view --flatten
kubectl --kubeconfig=./config  get node,all,cm -A


helm repo add coredns https://coredns.github.io/helm
helm pull coredns/coredns
helm --namespace=kube-system install coredns coredns/coredns
helm --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config --namespace=kube-system install coredns coredns/coredns --set replicaCount=3

--set replicaCount=3


cat <<EOF>14
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
kubectl --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config apply -f ./14
kubectl --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config get role kubeadm:bootstrap-signer-clusterinfo -n kube-public


kubeadm init phase bootstrap-token --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config

kubeadm token create --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config --print-join-command --ttl=24h

# kubectl --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config get secret bootstrap-token-tjtupk -n kube-system -o yaml



kubeadm token create --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config --print-join-command --ttl=24h
>>>> kubeadm join 12.0.100.97:6443 --token 40vzwg.frkcy0tz7yxjs0kt --discovery-token-ca-cert-hash sha256:f6f88fcbac3c50675a0dbcef5728d8fa0c2feb871d9a4b2c3158bc26b3cc4d90


kubectl drain node143 --delete-emptydir-data  --ignore-daemonsets
kubectl delete node node143


helm install cilium oci://quay.io/cilium/charts/cilium \
  --version 1.19.3 \
  --namespace kube-system \
  --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=12.0.100.97 \
  --set ipam.operator.clusterPoolIPv4PodCIDRList="244.2.0.0/16" \
  --set ipam.operator.clusterPoolIPv4MaskSize="24" \
  --set k8sServicePort=6443


helm upgrade cilium oci://quay.io/cilium/charts/cilium \
  --version 1.19.3 \
  --namespace kube-system \
  --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=12.0.100.97 \
  --set k8sServicePort=6443 \
  --reuse-values

#https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/admin/konnectivity/konnectivity-rbac.yaml
#https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/admin/konnectivity/konnectivity-agent.yaml

kubectl --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config apply -f RBAC-konnectivity-server.yaml
kubectl --kubeconfig /root/paas-kubernetes-chart-separated.deploy.3/config apply -f deploy-konnectivity-agent.yaml

registry.k8s.io/kas-network-proxy/proxy-server                           v0.34.0

        image: registry.k8s.io/kas-network-proxy/proxy-agent
        version: v0.34.0
        image: registry.k8s.io/kas-network-proxy/proxy-server
        version: v0.34.0
		
curl https://europe-north1-docker.pkg.dev/v2/k8s-artifacts-prod/images/kas-network-proxy/proxy-agent/tags/list | jq .tags

```
