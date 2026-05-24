#!/bin/sh
set -e
set -x

kubectl get -n cluster secret/paas-one-pki-admin-client -o json > k8s-ca.json

cat <<EOF>config
clusters:
- cluster:
    certificate-authority-data: `cat k8s-ca.json  | jq -r '.data."ca.crt"'`
    server: https://{{ .Values.global.advertiseAddress }}:6443
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


kubectl create secret generic paas-one-admin-config --from-file=./config -n cluster --dry-run=client -o yaml | kubectl apply -f -

kubectl get cm paas-one-kubeadm-config -n cluster -o jsonpath='{.data.k8s-kubeadm\.yaml}' > k8s-kubeadm.yaml

kubeadm init phase upload-config kubeadm --kubeconfig=./config --config ./k8s-kubeadm.yaml
kubeadm init phase upload-config kubelet --kubeconfig=./config --config ./k8s-kubeadm.yaml
kubeadm init phase bootstrap-token --kubeconfig=./config --config ./k8s-kubeadm.yaml --skip-token-print 



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


# kubectl --kubeconfig=./config  get node,all,cm -A
# kubeadm init phase addon kube-proxy  --kubeconfig ./config --config ./k8s-kubeadm.yaml



# kubectl --kubeconfig=./config get -n kube-public   configmap/cluster-info -o yaml
# kubectl --kubeconfig=./config  config view --flatten
# kubectl --kubeconfig=./config  get node,all,cm -A

kubectl --kubeconfig ./config get role kubeadm:bootstrap-signer-clusterinfo -n kube-public
kubeadm init phase bootstrap-token --kubeconfig ./config


helm repo add coredns https://coredns.github.io/helm
helm pull coredns/coredns
helm --kubeconfig ./config --namespace=kube-system upgrade --install coredns coredns/coredns --set replicaCount=3

helm upgrade --install cilium oci://quay.io/cilium/charts/cilium \
  --version 1.19.3 \
  --namespace kube-system \
  --kubeconfig ./config \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost={{ .Values.global.advertiseAddress }} \
  --set ipam.operator.clusterPoolIPv4PodCIDRList="{{ .Values.global.clusterCIDR }}" \
  --set ipam.operator.clusterPoolIPv4MaskSize="24" \
  --set k8sServicePort=6443

