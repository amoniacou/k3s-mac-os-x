#!/bin/bash
K3S_VERSION="1.24.8"
CERT_MANAGER="1.10.1"
NGINX_INGRESS="4.4.0"

if ![ -x "$(command -v k3d)" > /dev/null 2>&1 ]; then
  echo "The k3d binary is not available or not in your \$PATH"
  exit 1
fi

if ![ -x "$(command -v helm)" > /dev/null 2>&1 ]; then
  echo "The helm binary is not available or not in your \$PATH"
  exit 1
fi

if ![ -x "$(command -v kubectl)" > /dev/null 2>&1 ]; then
  echo "The kubectl binary is not available or not in your \$PATH"
  exit 1
fi

echo "Create a cluster"
registry_domain="docker.test"
registry_port=32000
version=
manifests=$(realpath ~/.k3d/k3s-cluster)
target=$(realpath ~/.k3d/k3s-cluster-registries.yaml)
echo "Create a manifests folder"
rm -rf ${manifests}
mkdir -p ${manifests} || exit 1
echo "Create a cert manager namespace manifest"
cat > "${manifests}/0-cert-manager-namespace.yml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
EOF
echo "Create an ingress namespace manifest"
cat > "${manifests}/0-ingress-nginx-namespace.yml" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
EOF
echo "Create a cert manager manifest"
cat > "${manifests}/2-cert-manager.yml" << EOF
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
  namespace: kube-system
spec:
  chart: cert-manager
  repo: https://charts.jetstack.io
  targetNamespace: cert-manager
  version: v${CERT_MANAGER}
  set:
    installCRDs: "true"
EOF
echo "Create a ingress manifest"
cat > "${manifests}/3-nginx-ingress.yml" << EOF
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: nginx-ingress
  namespace: kube-system
spec:
  chart: ingress-nginx
  repo: https://kubernetes.github.io/ingress-nginx
  targetNamespace: ingress-nginx
  version: ${NGINX_INGRESS}
  set:
   controller.publishService.enabled: "true"
EOF
#echo "Create a registries config for k3s"
#cat > $target << EOF
#mirrors:
#  "${registry_domain}:${registry_port}":
#    endpoint:
#      - http://${registry_domain}:${registry_port}
#EOF

echo "Create a cluster"
k3d cluster create k3s -p "80:80@loadbalancer" -p "443:443@loadbalancer" --wait \
  --volume "${manifests}:/var/lib/rancher/k3s/server/manifests@server:0" \
  --volume "${manifests}:/var/lib/rancher/k3s/server/manifests@agent:*" \
  --k3s-arg '--no-deploy=traefik@server:0' \
  --k3s-arg '--no-deploy=traefik@agent:*' \
  --image rancher/k3s:v${K3S_VERSION}-k3s1 || exit 1
echo "Merge k3s config"
k3d kubeconfig merge k3s --kubeconfig-switch-context || exit 1
echo "DO NOT FORGET TO EDIT coreedns with docker.test host"
echo "command for this: kubectl -n kube-system edit configmap coredns"
echo "After you need to kill coredns pod or via kubectl or via k9s"
echo "!!!IMPORTANT!!!"
echo "docker.test must have same IP as host.k3d.internal"
