#!/bin/bash
CLUSTER_SECRET=""
SED="sed -i\"\""

if [ -z $CLUSTER_SECRET ]; then
 CLUSTER_SECRET=$(cat /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1 | tr '[:upper:]' '[:lower:]')
 echo "No cluster secret given, generated secret: ${CLUSTER_SECRET}"
fi
target="/etc/rancher/k3s/registries.yaml"
registry_domain="docker.test"
registry_port=32000
manifests="/var/lib/rancher/k3s/server/manifests"
sudo mkdir -p /etc/rancher/k3s
sudo mkdir -p $manifests
sudo cat > $manifests/0-cert-manager-namespace.yml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
EOF
sudo cat > $manifests/0-ingress-nginx-namespace.yml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
EOF
sudo cat > $manifests/1-registry.yml << EOF
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: registry
  namespace: kube-system
spec:
  chart: docker-registry
  repo: https://helm.twun.io
  targetNamespace: default
  set:
    persistence.enabled: "true"
    persistence.deleteEnabled: "true"
    service.type: "NodePort"
    service.nodePort: "32000"
EOF
sudo cat > $manifests/2-cert-manager.yml << EOF
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
sudo cat > $manifests/3-nginx-ingress.yml << EOF
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
sudo cat > $target << EOF
mirrors:
  "${registry_domain}:${registry_port}":
    endpoint:
      - http://${registry_domain}:${registry_port}
EOF
\curl -sfL https://get.k3s.io | K3S_CLUSTER_SECRET=$CLUSTER_SECRET K3S_KUBECONFIG_MODE=644 INSTALL_K3S_EXEC="--disable traefik" sh -
echo "Disabling systemd dns resolver"
apt-get update
systemctl disable systemd-resolved
systemctl stop systemd-resolved
rm /etc/resolv.conf
echo nameserver 8.8.8.8 | tee /etc/resolv.conf
apt install -y dnsmasq
ip=$(hostname --all-ip-addresses | awk '{print $1}')
cat > /etc/dnsmasq.conf << EOF
no-resolv
domain-needed
bogus-priv
port=53
cache-size=1000
server=8.8.8.8
server=8.8.4.4
address=/test/$ip
EOF
systemctl restart dnsmasq
echo "nameserver $ip" | tee /etc/resolv.conf
