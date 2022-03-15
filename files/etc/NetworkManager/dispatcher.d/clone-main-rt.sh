#!/bin/bash

IFACE="$1"
STATE="$2"

if [[ "$STATE" = up ]]; then
	if [[ "$IFACE" =~ (eth|wlan)[0-9]+ ]]; then
		for index in `seq 0 $(($IP4_NUM_ROUTES - 1))`; do
			addr="IP4_ADDRESS_${index}"
			addr=${!addr}
			addr=$(echo $addr | cut -d'/' -f1)

			route="IP4_ROUTE_${index}"
			route=${!route}

			dest=$(echo $route | cut -d' ' -f1)
			metric=$(echo $route | cut -d' ' -f3)

			out="$dest dev $IFACE proto kernel scope link src $addr metric $metric"

			ip route add table wan $out

			logger -s "NetworkManager:$0: adding route $index to rt wan: $out"
		done
		default="default via $DHCP4_ROUTERS dev $IFACE proto dhcp metric $metric"
		ip route add table wan $default
		logger -s "NetworkManager:$0: adding default route to rt wan: $default"
	fi
fi

if [[ "$STATE" = down ]]; then
	if [[ "$IFACE" =~ (eth|wlan)[0-9]+ ]]; then
		ip route flush table wan
		logger -s "NetworkManager:$0: flushing rt wan"
	fi
fi

exit 0
