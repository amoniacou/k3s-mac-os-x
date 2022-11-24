# k3s-mac-os-x

Simple script to install local kubernetes cluster on mac os x via multipass and ubuntu via local run

## local docker registry

```sh
docker container run -d --name docker.test --restart always -p 32000:5000 registry:2
```

## Usage for mac os

Just run macos.sh:

```sh
./macos.sh
```

## Usage for ubuntu

Just run ubuntu.sh with sudo:

```sh
sudo ./ubuntu.sh
```

### Support

<a href="https://amoniac.eu" target="_blank"><img src="https://github.com/amoniacou/k3s-mac-os-x/blob/master/synthesized_by_amoniac.png?raw=true" alt="Sponsored by Amoniac OÜ" width="210"/></a>
