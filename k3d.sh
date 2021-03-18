#!/bin/bash
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
  version: v1.1
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
  repo: http://kubernetes.github.io/ingress-nginx
  targetNamespace: ingress-nginx
  version: 3.20.1
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

echo "Create a local registry"
k3d registry create k3s.localhost --port 0.0.0.0:32000 || exit 1
echo "Create a cluster"
k3d cluster create k3s -p "80:80@loadbalancer" -p "443:443@loadbalancer" --wait --volume "${manifests}:/var/lib/rancher/k3s/server/manifests@server[0];agent[*]" --registry-use k3d-k3s.localhost:32000 --k3s-server-arg '--no-deploy=traefik' --image rancher/k3s:v1.20.4-k3s1 || exit 1
echo "Merge k3s config"
k3d kubeconfig merge k3s --kubeconfig-switch-context || exit 1
