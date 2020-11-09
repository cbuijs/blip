#!/bin/bash

export LC_ALL="C"

cd /root/blip

/usr/bin/logger -s -t "BLIP" "Restoring / Updating / Loading Lists"

echo "Creating/Restoring IPSETs ..."
cat ipset.restore.txt | /usr/sbin/ipset -! -q restore
ipset list | grep -F " packets " | wc -l | gawk '{print "-- "$0" Entries in total"}'

##### IPv4 ##########
/usr/sbin/iptables -F BLIP
/usr/sbin/iptables -X BLIP
/usr/sbin/iptables -N BLIP

/usr/sbin/iptables -A forwarding_lan_rule -j BLIP
/usr/sbin/iptables -A forwarding_wan_rule -j BLIP
/usr/sbin/iptables -A input_lan_rule -j BLIP
/usr/sbin/iptables -A input_wan_rule -j BLIP

# Invalid
/usr/sbin/iptables -A BLIP -i pppoe-wan -m conntrack --ctstate INVALID -j LOG --log-prefix "DROP-INVALID wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -m conntrack --ctstate INVALID -j DROP

# New but not SYN
/usr/sbin/iptables -F NEWNOTSYN
/usr/sbin/iptables -X NEWNOTSYN
/usr/sbin/iptables -N NEWNOTSYN
/usr/sbin/iptables -A NEWNOTSYN -i pppoe-wan -p tcp --tcp-flags ACK,PSH ACK,PSH -j RETURN
/usr/sbin/iptables -A NEWNOTSYN -i pppoe-wan -p tcp --tcp-flags ACK ACK -j RETURN
/usr/sbin/iptables -A NEWNOTSYN -i pppoe-wan -p tcp -j LOG --log-prefix "DROP-NEW-NOT-SYN wan in: "
/usr/sbin/iptables -A NEWNOTSYN -i pppoe-wan -p tcp -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp ! --syn -m conntrack ! --ctstate ESTABLISHED,RELATED -j NEWNOTSYN

# XMAS
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL ALL -j LOG --log-prefix "DROP-XMAS1 wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL ALL -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL FIN,PSH,URG -j LOG --log-prefix "DROP-XMAS2 wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP

# Null
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "DROP-NULL wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL NONE -j DROP

# Bogus
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,SYN FIN,SYN -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags SYN,RST SYN,RST -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,RST FIN,RST -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,ACK FIN -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,ACK FIN -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,URG URG -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,URG URG -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,FIN FIN -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,FIN FIN -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,PSH PSH -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,PSH PSH -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j DROP
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

# Fragments
/usr/sbin/iptables -A BLIP -i pppoe-wan -f -j LOG --log-prefix "DROP-FRAGMENT: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -f -j DROP

# New (Logging only)
/usr/sbin/iptables -A BLIP -i pppoe-wan -p tcp --syn -j LOG --log-prefix "NEW-TCP wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p udp ! --sport 1:1023 --dport 1:1023 -m conntrack ! --ctstate ESTABLISHED -j LOG --log-prefix "NEW-UDP wan in: "
/usr/sbin/iptables -A BLIP -i pppoe-wan -p icmp -m conntrack --ctstate NEW -j LOG --log-prefix "NEW-ICMP wan in: "

# Allow
while read MAC DUMMY
do
	echo "Hard-Allow MAC: ${MAC}"
	/usr/sbin/iptables -A BLIP -o pppoe-wan -m conntrack --ctstate NEW -m mac --mac-source ${MAC} -j RETURN
done < mac.allow.list

while read SET DIR DUMMY
do
	echo "Activating ${SET} (${DIR}) ..."

	if [ "${DIR}" == "OUT" -o "${DIR}" == "BOTH" ] ; then
		/usr/sbin/iptables -A BLIP -o pppoe-wan -m conntrack --ctstate NEW -m set --match-set ${SET} dst -j RETURN
	fi

	if [ "${DIR}" == "IN" -o "${DIR}" == "BOTH" ] ; then
		/usr/sbin/iptables -A BLIP -i pppoe-wan -m conntrack --ctstate NEW -m set --match-set ${SET} src -j RETURN
	fi
done < allow_4.blip.list

# Block
while read SET DIR DUMMY
do
	echo "Activating ${SET} (${DIR})..."

	if [ "${DIR}" == "OUT" -o "${DIR}" == "BOTH" ] ; then
		/usr/sbin/iptables -A BLIP -o pppoe-wan -m set --match-set ${SET} dst -m limit --limit 10/sec -j LOG --log-prefix "${SET}-RJCT wan out: "
		/usr/sbin/iptables -A BLIP -o pppoe-wan -m set --match-set ${SET} dst -j REJECT --reject-with host-unreach
	fi

	if [ "${DIR}" == "IN" -o "${DIR}" == "BOTH" ] ; then
		/usr/sbin/iptables -A BLIP -i pppoe-wan -m set --match-set ${SET} src -m limit --limit 10/sec -j LOG --log-prefix "${SET}-DROP wan in: "
		/usr/sbin/iptables -A BLIP -i pppoe-wan -m set --match-set ${SET} src -j DROP
	fi
done < block_4.blip.list


##### IPv6 ##########
/usr/sbin/ip6tables -F BLIP
/usr/sbin/ip6tables -X BLIP
/usr/sbin/ip6tables -N BLIP

/usr/sbin/ip6tables -A forwarding_lan_rule -j BLIP
/usr/sbin/ip6tables -A forwarding_wan_rule -j BLIP
/usr/sbin/ip6tables -A input_lan_rule -j BLIP
/usr/sbin/ip6tables -A input_wan_rule -j BLIP

# Invalid
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -m conntrack --ctstate INVALID -j LOG --log-prefix "DROP-INVALID wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -m conntrack --ctstate INVALID -j DROP

# New but not SYN
/usr/sbin/ip6tables -F NEWNOTSYN
/usr/sbin/ip6tables -X NEWNOTSYN
/usr/sbin/ip6tables -N NEWNOTSYN
/usr/sbin/ip6tables -A NEWNOTSYN -i pppoe-wan -p tcp --tcp-flags ACK,PSH ACK,PSH -j RETURN
/usr/sbin/ip6tables -A NEWNOTSYN -i pppoe-wan -p tcp --tcp-flags ACK ACK -j RETURN
/usr/sbin/ip6tables -A NEWNOTSYN -i pppoe-wan -p tcp -j LOG --log-prefix "DROP-NEW-NOT-SYN wan in: "
/usr/sbin/ip6tables -A NEWNOTSYN -i pppoe-wan -p tcp -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp ! --syn -m conntrack ! --ctstate ESTABLISHED,RELATED -j NEWNOTSYN

# XMAS
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL ALL -j LOG --log-prefix "DROP-XMAS1 wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL ALL -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL FIN,PSH,URG -j LOG --log-prefix "DROP-XMAS2 wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP

# Null
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "DROP-NULL wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL NONE -j DROP

# Bogus
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,SYN FIN,SYN -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags SYN,RST SYN,RST -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,RST FIN,RST -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,ACK FIN -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags FIN,ACK FIN -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,URG URG -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,URG URG -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,FIN FIN -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,FIN FIN -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,PSH PSH -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ACK,PSH PSH -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j DROP
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j LOG --log-prefix "DROP-BOGUS wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

# New (Logging only)
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p tcp --syn -j LOG --log-prefix "NEW-TCP wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p udp ! --sport 1:1023 --dport 1:1023 -m conntrack ! --ctstate ESTABLISHED -j LOG --log-prefix "NEW-UDP wan in: "
/usr/sbin/ip6tables -A BLIP -i pppoe-wan -p ipv6-icmp -m conntrack --ctstate NEW -j LOG --log-prefix "NEW-ICMP wan in: "

# Allow
while read MAC DUMMY
do
	echo "Hard-Allow MAC: ${MAC}"
	/usr/sbin/ip6tables -A BLIP -o pppoe-wan -m conntrack --ctstate NEW -m mac --mac-source ${MAC} -j RETURN
done < mac.allow.list

while read SET DIR DUMMY
do
	echo "Activating ${SET} (${DIR})..."

	if [ "${DIR}" == "OUT" -o "${DIR}" == "BOTH" ] ; then
		/usr/sbin/ip6tables -A BLIP -o pppoe-wan -m conntrack --ctstate NEW -m set --match-set ${SET} dst -j RETURN
	fi

	if [ "${DIR}" == "IN" -o "${DIR}" == "BOTH" ] ; then
		/usr/sbin/ip6tables -A BLIP -i pppoe-wan -m conntrack --ctstate NEW -m set --match-set ${SET} src -j RETURN
	fi
done < allow_6.blip.list

# Block
while read SET DIR DUMMY
do
	echo "Activating ${SET} (${DIR})..."

	if [ "${DIR}" == "OUT" -o "${DIR}" == "BOTH" ] ; then
		/usr/sbin/ip6tables -A BLIP -o pppoe-wan -m set --match-set ${SET} dst -m limit --limit 10/sec -j LOG --log-prefix "${SET}-RJCT wan out: "
		/usr/sbin/ip6tables -A BLIP -o pppoe-wan -m set --match-set ${SET} dst -j REJECT --reject-with addr-unreach
	fi

	if [ "${DIR}" == "IN" -o "${DIR}" == "BOTH" ] ; then
		/usr/sbin/ip6tables -A BLIP -i pppoe-wan -m set --match-set ${SET} src -m limit --limit 10/sec -j LOG --log-prefix "${SET}-DROP wan in: "
		/usr/sbin/ip6tables -A BLIP -i pppoe-wan -m set --match-set ${SET} src -j DROP
	fi
done < block_6.blip.list

exit 0

