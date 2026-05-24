# PaaS Kubernetes Helm Chart (Separated Deployments)

This Helm chart deploys the Kubernetes control plane components for a PaaS environment with **separate deployments** (one pod per deployment):
- kube-apiserver
- kube-scheduler
- kube-controller-manager
- konnectivity-server

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Existing secrets and configmaps referenced in values.yaml

## Installation

### Install the chart
```bash
helm install my-release ./paas-kubernetes-chart-separated
```

### Install with custom values
```bash
helm install my-release ./paas-kubernetes-chart-separated -f custom-values.yaml
```

### Install only specific components
You can enable/disable individual components by setting the `enabled` flag in values.yaml:

```yaml
kubeApiserver:
  enabled: true
kubeScheduler:
  enabled: true
kubeControllerManager:
  enabled: true
konnectivityServer:
  enabled: true
```

Or via command line:
```bash
helm install my-release ./paas-kubernetes-chart-separated --set kubeScheduler.enabled=false
```

## Configuration

The following table lists the configurable parameters of the PaaS Kubernetes chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.namespace` | Target namespace for deployment | `cluster1` |
| `global.clusterName` | Name of the cluster | `paas` |
| `kubeApiserver.enabled` | Enable kube-apiserver deployment | `true` |
| `kubeApiserver.replicaCount` | Number of kube-apiserver replicas | `3` |
| `kubeScheduler.enabled` | Enable kube-scheduler deployment | `true` |
| `kubeScheduler.replicaCount` | Number of kube-scheduler replicas | `2` |
| `kubeControllerManager.enabled` | Enable kube-controller-manager deployment | `true` |
| `kubeControllerManager.replicaCount` | Number of kube-controller-manager replicas | `2` |
| `konnectivityServer.enabled` | Enable konnectivity-server deployment | `true` |
| `konnectivityServer.replicaCount` | Number of konnectivity-server replicas | `2` |
| `images.kubeApiserver.repository` | kube-apiserver image repository | `harbor.iblog.pro/registry.k8s.io/kube-apiserver` |
| `images.kubeApiserver.tag` | kube-apiserver image tag | `v1.36.1` |
| `images.kubeApiserver.pullPolicy` | Image pull policy | `Always` |
| `images.kubeScheduler.repository` | kube-scheduler image repository | `harbor.iblog.pro/registry.k8s.io/kube-scheduler` |
| `images.kubeScheduler.tag` | kube-scheduler image tag | `v1.36.1` |
| `images.kubeScheduler.pullPolicy` | Image pull policy | `IfNotPresent` |
| `images.kubeControllerManager.repository` | kube-controller-manager image repository | `harbor.iblog.pro/registry.k8s.io/kube-controller-manager` |
| `images.kubeControllerManager.tag` | kube-controller-manager image tag | `v1.36.1` |
| `images.kubeControllerManager.pullPolicy` | Image pull policy | `IfNotPresent` |
| `images.konnectivityServer.repository` | konnectivity-server image repository | `registry.k8s.io/kas-network-proxy/proxy-server` |
| `images.konnectivityServer.tag` | konnectivity-server image tag | `v0.34.0` |
| `images.konnectivityServer.pullPolicy` | Image pull policy | `Always` |
| `kubeApiserver.advertiseAddress` | API server advertise address | `12.0.100.94` |
| `kubeApiserver.securePort` | API server secure port | `6443` |
| `kubeApiserver.serviceClusterIPRange` | Service cluster IP range | `244.1.0.0/16` |
| `kubeApiserver.etcdServers` | List of etcd server endpoints | `["https://etcd-0.etcd-headless.cluster1.svc:2379", ...]` |
| `kubeApiserver.etcdPrefix` | etcd prefix | `/cluster1_paas` |
| `kubeApiserver.authorizationMode` | Authorization mode | `Node,RBAC` |
| `kubeApiserver.enableAdmissionPlugins` | Enabled admission plugins | `ResourceQuota,LimitRanger` |
| `kubeControllerManager.clusterCIDR` | Cluster CIDR | `244.2.0.0/16` |
| `kubeControllerManager.clusterName` | Cluster name | `paas` |
| `konnectivity.agentPort` | Konnectivity agent port | `16443` |
| `konnectivity.adminPort` | Konnectivity admin port | `8133` |
| `konnectivity.healthPort` | Konnectivity health port | `8134` |
| `secrets.apiServerCertificate` | API server certificate secret name | `paas-api-server-certificate` |
| `secrets.ca` | CA certificate secret name | `paas-ca` |
| `secrets.schedulerKubeconfig` | Scheduler kubeconfig secret name | `paas-scheduler-kubeconfig` |
| `secrets.controllerManagerKubeconfig` | Controller manager kubeconfig secret name | `paas-controller-manager-kubeconfig` |
| `secrets.konnectivityKubeconfig` | Konnectivity kubeconfig secret name | `paas-konnectivity-kubeconfig` |
| `configMaps.auditPolicy` | Audit policy configmap name | `tenant-audit-policy` |
| `configMaps.konnectivityEgressSelector` | Konnectivity egress selector configmap name | `paas-konnectivity-egress-selector-configuration` |

### Resource Limits

To configure resource limits for each component, modify the `resources` section in `values.yaml`:

```yaml
kubeApiserver:
  resources:
    limits:
      cpu: 500m
      memory: 1Gi
    requests:
      cpu: 250m
      memory: 512Mi

kubeScheduler:
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 128Mi

kubeControllerManager:
  resources:
    limits:
      cpu: 200m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi

konnectivityServer:
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 128Mi
```

## Deployed Resources

This chart creates the following Kubernetes resources (when enabled):

| Resource | Name | Description |
|----------|------|-------------|
| Deployment | `<release-name>-apiserver` | kube-apiserver deployment |
| Deployment | `<release-name>-scheduler` | kube-scheduler deployment |
| Deployment | `<release-name>-controller-manager` | kube-controller-manager deployment |
| Deployment | `<release-name>-konnectivity` | konnectivity-server deployment |

## Upgrading

```bash
helm upgrade my-release ./paas-kubernetes-chart-separated
```

## Uninstalling

```bash
helm uninstall my-release
```

## Secrets and ConfigMaps

This chart expects the following secrets and configmaps to exist in the target namespace:

### Secrets
- `paas-api-server-certificate` - API server TLS certificate
- `paas-ca` - CA certificate
- `paas-api-server-kubelet-client-certificate` - Kubelet client certificate
- `paas-front-proxy-ca-certificate` - Front proxy CA certificate
- `paas-front-proxy-client-certificate` - Front proxy client certificate
- `paas-sa-certificate` - Service account certificate
- `paas-datastore-certificate` - Datastore (etcd) certificate
- `paas-scheduler-kubeconfig` - Scheduler kubeconfig
- `paas-controller-manager-kubeconfig` - Controller manager kubeconfig
- `paas-konnectivity-kubeconfig` - Konnectivity kubeconfig

### ConfigMaps
- `tenant-audit-policy` - Audit policy configuration
- `paas-konnectivity-egress-selector-configuration` - Konnectivity egress selector configuration

## Differences from Combined Chart

This chart differs from the combined chart in the following ways:

1. **Separate Deployments**: Each component runs in its own deployment with its own pods
2. **Independent Scaling**: Each component can be scaled independently
3. **Component Enable/Disable**: Individual components can be enabled or disabled
4. **Granular Resource Management**: Resources can be configured per component
5. **Independent Updates**: Each component can be updated independently

## License

This chart is provided as-is for use in PaaS environments.
