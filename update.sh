#!/bin/bash

# TODO:
# - Collapse the different types in same routines, unduplicating.
# - Aggregation of IP's
# - Remove any overlaps with allow/blocklists (remove allowed IPs from blocklists where possible)
# - Add option to specify if rules need to be applied on incoming-only, outgoing-only or both
# - Simplify variables and such

export LC_ALL="C"

cd /root/blip

if [ "${1}" != "" ] ; then
	rm -f update.running
fi

if [ -f update.running ] ; then
	echo "Already updating !"
	exit 1
fi

echo "Blah" > update.running

/usr/bin/logger -s -t "BLIP" "Updating / Fetching lists"

rm -f *.tmp ipset.restore.txt blip.list

IPRX4="((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}(/(3[0-2]|[12]?[0-9]))*)"
IPRX6="(((:(:[0-9a-f]{1,4}){1,7}|::|[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){1,6}|::|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){1,5}|::|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){1,4}|::|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){1,3}|::|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){1,2}|::|:[0-9a-f]{1,4}(::[0-9a-f]{1,4}|::|:[0-9a-f]{1,4}(::|:[0-9a-f]{1,4}))))))))|(:(:[0-9a-f]{1,4}){0,5}|[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){0,4}|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){0,3}|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){0,2}|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4})?|:[0-9a-f]{1,4}(:|:[0-9a-f]{1,4})))))):(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3})(/(12[0-8]|1[01][0-9]|[1-9]?[0-9]))*)"
IPRX="^(${IPRX4}|${IPRX6})$"

echo "Getting GeoNames Codes ..."
wget -q --show-progress "https://raw.githubusercontent.com/cbuijs/accomplist/master/chris/geonames-id-continents.list" -O - | gawk -F"\t" '{ print $2"\t"$3 }' | sort -k1,1 > regions.tmp
wget -q --show-progress "https://raw.githubusercontent.com/cbuijs/accomplist/master/chris/geonames-id-regions.list" -O - | gawk -F"\t" '{ print $2"\t"$3 }' | sort -k1,1 >> regions.tmp
sort -k1,1 regions.tmp > regions.list

wget -q --show-progress "https://raw.githubusercontent.com/cbuijs/accomplist/master/chris/geonames-id-countries.list" -O - | gawk -F"\t" '{ print $3"\t"$2 }' | sort -k1,1 > countries.list

/sbin/ip addr show pppoe-wan | grep -ioE "inet6* [^ ]+" | cut -d" " -f2 > local.addr.tmp
/sbin/ip -f inet route show dev pppoe-wan | tr -s "[:blank:]" "\t" | cut -f1  >> local.addr.tmp
/sbin/ip -f inet6 route show dev pppoe-wan | tr -s "[:blank:]" "\t" | cut -f1 >> local.addr.tmp
cat local.addr.tmp | ./aggrip -a1 > local.addr.list

cat local.addr.list

if [ "${1}" != "" ] ; then
	rm -rf cache/
fi

mkdir -p cache

grep -vE "^(#.*|[[:blank:]]*)$" sources.list > sources.tmp

while read NAME EXPIRE TYPE BW DIR DATA
do
	NAME="${NAME,,}"
	TYPE="${TYPE,,}"
	BW="${BW,,}"

	case ${TYPE^^} in
		ASN)
			for ASN in `echo "${DATA}" | tr " " "\n" | sort -g | paste -sd" "`
			do
				echo -e "\nFetching ASN ${BW}list ${ASN^^} ..."
				if [ -s "cache/as${ASN}.${BW}.timestamp" ] ; then
					NOW=`date +%s`
					TIMESTAMP=`head -n1 "cache/as${ASN}.${BW}.timestamp"`
					if [ $(( NOW - TIMESTAMP )) -gt ${EXPIRE} ] ; then
						rm -f "cache/as${ASN}.${BW}.timestamp"
					fi
				fi

				if [ -s "cache/as${ASN}.${BW}.timestamp" ] ; then
					echo "-- Refresh from CACHE ..."
				else
					echo "-- Refresh from RIPE ..."
					date +%s > cache/as${ASN}.${BW}.timestamp
					wget -q "https://stat.ripe.net/data/announced-prefixes/data.json?resource=${ASN}" -O - | jq ".data.prefixes[].prefix" | cut -d"\"" -f2 > prefix.tmp
					grep -iE "${IPRX4}" prefix.tmp | ./aggrip -a1 > cache/as${ASN}.${BW}.ipv4.list
					grep -iE "${IPRX6}" prefix.tmp | ./aggrip -a1 > cache/as${ASN}.${BW}.ipv6.list
					echo "${DIR}" > cache/as${ASN}.${BW}.dir
				fi
				cat cache/as${ASN}.${BW}.ipv?.list | wc -l | gawk '{ print "-- "$0" Entries" }'
				echo "as${ASN}.${BW}" >> blip.list
			done
			;;
		COUNTRY)
			for COUNTRY in `echo "${DATA}" | tr " " "\n" | sort | paste -sd" "`
			do
				CNAME="${NAME,,}-${COUNTRY,,}"
				CCNAME=`grep -E "^${COUNTRY^^}[[:blank:]]" countries.list | cut -f2 | sed ':a;{N;s/\n/, /};ba'`

				echo -e "\nFetching COUNTRY ${BW}list ${COUNTRY^^} (${NAME}: ${CCNAME}) ..."
				if [ -s "cache/${NAcountry-ME}.${BW}.timestamp" ] ; then
					NOW=`date +%s`
					TIMESTAMP=`head -n1 "cache/${CNAME}.${BW}.timestamp"`
					if [ $(( NOW - TIMESTAMP )) -gt ${EXPIRE} ] ; then
						rm -f "cache/${CNAME}.${BW}.timestamp"
					fi
				fi

				if [ -s "cache/${CNAME}.${BW}.timestamp" ] ; then
					echo "-- Refresh from CACHE ..."
				else
					date +%s > cache/${CNAME}.${BW}.timestamp
					echo "${DIR}" > cache/${CNAME}.${BW}.dir

					#echo "-- Refresh from RIPE ..."
					#wget -q "https://stat.ripe.net/data/country-resource-list/data.json?resource=${COUNTRY,,}&v4_format=prefix" -O json.tmp
					#cat json.tmp | jq ".data.resources.ipv4[]" | cut -d"\"" -f2 | ./aggrip -a1 > cache/${CNAME}.${BW}.ipv4.list
					#cat json.tmp | jq ".data.resources.ipv6[]" | cut -d"\"" -f2 | ./aggrip -a1 > cache/${CNAME}.${BW}.ipv6.list

					# Use ipdeny
					#echo "-- Refresh from IPDENY ..."
					wget -q "https://www.ipdeny.com/ipblocks/data/aggregated/${COUNTRY,,}-aggregated.zone" -O - | ./aggrip -a1 > cache/${CNAME}.${BW}.ipv4.list
					wget -q "https://www.ipdeny.com/ipv6/ipaddresses/aggregated/${COUNTRY,,}-aggregated.zone" -O - | ./aggrip -a1 > cache/${CNAME}.${BW}.ipv6.list

				fi
				cat cache/${CNAME,,}.${BW}.ipv?.list | wc -l | gawk '{ print "-- "$0" Entries" }'
				echo "${CNAME,,}.${BW}" >> blip.list
			done
			;;
		LIST)
			echo -e "\nFetching LIST ${BW}list ${NAME^^} ..."
			if [ -s "cache/${NAME}.${BW}.timestamp" ] ; then
				NOW=`date +%s`
				TIMESTAMP=`head -n1 "cache/${NAME}.${BW}.timestamp"`
				if [ $(( NOW - TIMESTAMP )) -gt ${EXPIRE} ] ; then
					rm -f "cache/${NAME}.${BW}.timestamp"
				fi
			fi

			if [ -s "cache/${NAME}.${BW}.timestamp" ] ; then
				echo "-- Refresh from CACHE ..."
			else
				echo "-- Refresh from LIST ..."
				date +%s > cache/${NAME}.${BW}.timestamp
				grep -iE "${IPRX4}" ${DATA} | ./aggrip -a1 > cache/${NAME}.${BW}.ipv4.list
				grep -iE "${IPRX6}" ${DATA} | ./aggrip -a1 > cache/${NAME}.${BW}.ipv6.list
				echo "${DIR}" > cache/${NAME}.${BW}.dir
			fi
			cat cache/${NAME}.${BW}.ipv?.list | wc -l | gawk '{ print "-- "$0" Entries" }'
			echo "${NAME}.${BW}" >> blip.list
			;;
		URL)
			echo -e "\nFetching URL ${BW}list ${NAME^^} ..."
			if [ -s "cache/${NAME}.${BW}.timestamp" ] ; then
				NOW=`date +%s`
				TIMESTAMP=`head -n1 "cache/${NAME}.${BW}.timestamp"`
				if [ $(( NOW - TIMESTAMP )) -gt ${EXPIRE} ] ; then
					rm -f "cache/${NAME}.${BW}.*"
				fi
			fi

			if [ -s "cache/${NAME}.${BW}.timestamp" ] ; then
					echo "-- Refresh from CACHE ..."
			else
				date +%s > cache/${NAME}.${BW}.timestamp
				echo "${DIR}" > cache/${NAME}.${BW}.dir
				for URL in ${DATA}
				do
					echo "-- Refresh from URL ${URL} ..."
					wget -q "${URL}" -O - | gawk '{ print $1 }' | cut -f1 | grep -iE "${IPRX}" > list.tmp
					cat list.tmp | wc -l | gawk '{ print "---- "$0" Entries" }'
					grep -iE "${IPRX4}" list.tmp | ./aggrip -a1 >> cache/${NAME}.${BW}.ipv4.list
					grep -iE "${IPRX6}" list.tmp | ./aggrip -a1 >> cache/${NAME}.${BW}.ipv6.list
				done
			fi

			cat cache/${NAME}.${BW}.ipv4.list | ./aggrip -a1 > new.tmp
			mv -f new.tmp cache/${NAME}.${BW}.ipv4.list

			cat cache/${NAME}.${BW}.ipv6.list | ./aggrip -a1 > new.tmp
			mv -f new.tmp cache/${NAME}.${BW}.ipv6.list

			cat cache/${NAME}.${BW}.ipv?.list | wc -l | gawk '{ print "-- "$0" Entries" }'
			echo "${NAME}.${BW}" >> blip.list
			;;
		*)
			echo "Unknown type \"${TYPE}\" !"
			;;
	esac
	#sleep 1
done < sources.tmp


ls -1 cache/*.list | cut -d"." -f3 | sed "s/ipv//g" | sort -n | uniq > fam.tmp

rm -f *.blip.list
echo "flush" > ipset.restore.txt
echo "destroy" >> ipset.restore.txt

while read FAM
do
	#ls -1 -t -r cache/*.${BW}.ipv${FAM}.list > files.tmp
	while read BLIP
	do
		FILE="cache/${BLIP}.ipv${FAM}.list"
		if [ -s ${FILE} ] ; then
			NAME=`basename ${FILE} | cut -d"." -f1`
			BW=`basename ${FILE} | cut -d"." -f2`
			SET="BLIP_${NAME^^}_${FAM^^}"
			SET="${SET:0:32}"
			INET="inet"
			if [ "${FAM}" == "6" ] ; then
				INET="${INET}6"
			fi
			LEN=`cat ${FILE} | wc -l`

			echo "Building set ${SET} with ${LEN} entries from ${FILE} ..."

			#echo "create ${SET} hash:net family ${INET} hashsize 64 maxelem $(( LEN + 64 )) counters" >> ipset.restore.txt
			echo "create ${SET} hash:net family ${INET} hashsize 64 maxelem $(( LEN + 1 )) counters" >> ipset.restore.txt
			gawk -v VAL=${SET} '{ print "add "VAL" " $0" packets 0 bytes 0" }' ${FILE} >> ipset.restore.txt

			DIR=`head -n1 cache/${NAME}.${BW}.dir`

			echo -e "${SET}\t${DIR^^}" >> ${BW,,}_${FAM,,}.blip.list
		fi
	#done < files.tmp
	done < blip.list
done < fam.tmp

echo "Making/Aggregating flatt ALL lists ..."
cat cache/*.allow.ipv4.list | ./aggrip -a1 > all.allow.ipv4.list
cat cache/*.block.ipv4.list | ./aggrip -a1 > all.block.ipv4.list
cat cache/*.allow.ipv6.list | ./aggrip -a1 > all.allow.ipv6.list
cat cache/*.block.ipv6.list | ./aggrip -a1 > all.block.ipv6.list

/etc/init.d/firewall restart

rm -f update.running *.tmp

echo "BLIP Update done!"

exit 0

