# blip
OpenWRT IPSET allow/blocklist generator

Supports LIST (FILE), ASN, Country and URL. See sources.list for examples.

Install in /root/blip.

Run update.sh to update the IPSETs. Run with "init" parameter to force update. Otherwise lists are taken from cache with a TTL of 4 hours (every 4 hours refresh when run).

Stick run.sh in firewall.user.

Better documentation to come/wip.

Disclaimer:
Use at own risk. The lists included are based on day-2-day monitoing and contain MASSIVE amounts of false-positives.

Reference:
Loosly based on and inspired by <a href="https://github.com/openwrt/packages/tree/master/net/banip/files">BanIP</a> by <a href="dev@brenken.org">Dirk Brenken</a>

