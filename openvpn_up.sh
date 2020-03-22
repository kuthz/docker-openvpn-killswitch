#!/usr/bin/env bash
echo 'Update local dnsmasq /var/dnsmasq/resolv.conf to use VPN dns servers'
/etc/openvpn/update-resolv-conf || true
resolvconf -u || true
