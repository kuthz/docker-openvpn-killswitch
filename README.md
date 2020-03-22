# Docker openvpn killswitch

Docker image with openvpn / iptables / dnsmasq

Everything is lock by default, only the VPN endpoint is allowed by default
All traffic go through the VPN connection 

## Instruction and Usage

### Build

```
docker build -t openvpn-killswitch .
```

### Usage

#### Docker

```
docker run \
    -it \
    --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    -e OPENVPN_CONFIG=openvpn file to use without .ovpn extension \
    -e LOCAL_NETWORK=local network subnet to allow traffic (example: 192.168.1.0/24) \
    -e OPENVPN_OPTS=extra openvpn options \
    -v path to data:/etc/openvpn/profile/ \
    openvpn-killswitch
```

#### Docker-compose

Compatible with docker-compose v2 schemas.

```
version: "2"
services:
  openvpn:
    image: kuthz/openvpn-killswitch
    container_name: openvpn
    cap_add:
        - NET_ADMIN
    devices:
        - /dev/net/tun
    volumes:
        - path to data:/etc/openvpn/profile/
    environment:
        - OPENVPN_CONFIG=openvpn file to use without .ovpn extension
        - LOCAL_NETWORK=local network subnet to allow traffic (example: 192.168.1.0/24)
        - OPENVPN_OPTS=extra openvpn options
```

### Openvpn

If the .ovpn don't include the credentials in it, you can add a file `.credentials` in the `path to data` folder

The file must contains these information
```
<username>
<password>
```