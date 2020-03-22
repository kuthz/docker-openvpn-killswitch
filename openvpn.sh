#!/bin/sh
echo 'Block everything at start'
# Flush all rules
iptables --flush

# Set default policy
iptables --policy FORWARD DROP
iptables --policy OUTPUT  DROP
iptables --policy INPUT   DROP

if [ ! -z "$OPENVPN_CONFIG" ]
then
 if [ -f profile/"${OPENVPN_CONFIG}".ovpn ]
 then
  echo "Starting OpenVPN using config ${OPENVPN_CONFIG}.ovpn"
  OPENVPN_CONFIG=profile/${OPENVPN_CONFIG}.ovpn
 else
  echo "Supplied config ${OPENVPN_CONFIG}.ovpn could not be found."
  exit 1
 fi
else
 echo "No VPN configuration provided."
 exit 1
fi

if [ -f profile/.credentials ]
 then
   OPENVPN_AUTH="--auth-user-pass profile/.credentials"
fi

eval $(awk '/remote / { split($0,a," "); print "OPENVPN_SERVER_IP="a[2]"\nOPENVPN_SERVER_PORT="a[3]"" }' $OPENVPN_CONFIG)
eval $(awk '/proto/ { split($0,a," "); print "OPENVPN_SERVER_PROTO="a[2]"" }' $OPENVPN_CONFIG)

# Detect if OPENVVPN_SERVER_IP is a domain
IS_OPENVPN_DNS=$(echo $OPENVPN_SERVER_IP | grep -P "^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$")
if [ -n "$IS_OPENVPN_DNS" ]
then
  echo "OpenVPN is using domain name, configure local dnsmasq"
  VPN_DNS_NAME=$(echo $OPENVPN_SERVER_IP | sed 's/.*\.\(.*\..*\)/\1/')

  echo "server=/$VPN_DNS_NAME/127.0.0.11" > /etc/dnsmasq.conf
fi

# Force to use local dnsmasq, override docker dnsmasq
echo "nameserver 127.0.0.1" > /etc/resolv.conf
service dnsmasq start

echo "Configure to allow $OPENVPN_SERVER_IP:$OPENVPN_SERVER_PORT:$OPENVPN_SERVER_PROTO only"

# Allow all on loopback
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT  -i lo -j ACCEPT

# We want to allow DNS request from docker network
iptables -A OUTPUT -o eth0 -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -o eth0 -p udp --dport 53 -j ACCEPT

iptables -A INPUT -i eth0 -p tcp --sport 53 -j ACCEPT
iptables -A INPUT -i eth0 -p udp --sport 53 -j ACCEPT

# Allow VPN connection on eth0
iptables -A OUTPUT -o eth0 -d $OPENVPN_SERVER_IP -p $OPENVPN_SERVER_PROTO --dport $OPENVPN_SERVER_PORT -j ACCEPT
iptables -A INPUT  -i eth0 -s $OPENVPN_SERVER_IP -p $OPENVPN_SERVER_PROTO --sport $OPENVPN_SERVER_PORT -j ACCEPT

# Allow ALL on tun0
iptables -A OUTPUT -o tun0 -d 0.0.0.0/0 -j ACCEPT
iptables -A INPUT  -i tun0 -s 0.0.0.0/0 -j ACCEPT

eval $(/sbin/ip r l | awk '{if($5!="tun0"){print "GW="$3"\nINT="$5; exit}}')
if [ -n "${GW-}" -a -n "${INT-}" ]; then
    # Allow communication from the docker gateway, needed for docker MAC
    iptables -A OUTPUT -o "$INT" -d "$GW" -j ACCEPT
    iptables -A INPUT  -i "$INT" -s "$GW" -j ACCEPT

    if [ -n "${LOCAL_NETWORK-}" ]; then
        echo "adding route to local network $LOCAL_NETWORK via $GW dev $INT"
        /sbin/ip r a "$LOCAL_NETWORK" via "$GW" dev "$INT"
        # Allow private networks on eth0
        iptables -A OUTPUT -o "$INT" -d $LOCAL_NETWORK -j ACCEPT
        iptables -A INPUT  -i "$INT" -s $LOCAL_NETWORK -j ACCEPT
    fi
fi

openvpn $OPENVPN_OPTS --script-security 2 --up /etc/openvpn/openvpn_up.sh --config "$OPENVPN_CONFIG" $OPENVPN_AUTH
