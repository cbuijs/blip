#!/bin/bash

cd /root/blip

if [ -f update.running ] ; then
        echo "Already updating !"
        exit 1
fi

echo "Blah" > update.running

export LC_ALL="C"

IPRX4="((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}(/(3[0-2]|[12]?[0-9]))*)"
IPRX6="(((:(:[0-9a-f]{1,4}){1,7}|::|[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){1,6}|::|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){1,5}|::|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){1,4}|::|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){1,3}|::|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){1,2}|::|:[0-9a-f]{1,4}(::[0-9a-f]{1,4}|::|:[0-9a-f]{1,4}(::|:[0-9a-f]{1,4}))))))))|(:(:[0-9a-f]{1,4}){0,5}|[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){0,4}|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){0,3}|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4}){0,2}|:[0-9a-f]{1,4}(:(:[0-9a-f]{1,4})?|:[0-9a-f]{1,4}(:|:[0-9a-f]{1,4})))))):(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3})(/(12[0-8]|1[01][0-9]|[1-9]?[0-9]))*)"
IPRX="^(${IPRX4}|${IPRX6})$"

LINE=`grep -iE "^${1^^}[[:blank:]].*[[:blank:]]URL[[:blank:]]" sources.list`

if [ "${LINE}" != "" ] ; then
	IFS="	" read NAME EXPIRE TYPE BW DIR URLS <<< ${LINE}

	NAME="${NAME,,}"
        TYPE="${TYPE,,}"
        BW="${BW,,}"
	DIR="${DIR^^}"

	rm -f cache/${NAME}.${BW}.*

	date +%s > cache/${NAME}.${BW}.timestamp
	echo "${DIR}" > cache/${NAME}.${BW}.dir

	echo "Updating ${NAME} ..."
	for URL in ${URLS}
	do
		echo "-- Refresh from URL ${URL} ..."
		wget -q "${URL}" -O - | gawk '{ print $1 }' | grep -iE "${IPRX}" > list.tmp
		grep -iE "${IPRX4}" list.tmp | ./aggrip -a1 >> cache/${NAME}.${BW}.ipv4.list
		grep -iE "${IPRX6}" list.tmp | ./aggrip -a1 >> cache/${NAME}.${BW}.ipv6.list
	done

	ls -1 cache/${NAME}.${BW}.ipv?.list > files.tmp

	while read FILE
	do
		if [ -s ${FILE} ] ; then
			NAME=`basename ${FILE} | cut -d"." -f1`
			FAM=`echo ${FILE} | grep -oE "ipv[46]" | grep -oE "[46]"`
			SET="BLIP_${NAME^^}_${FAM^^}"
			SET="${SET:0:32}"

			CLEN=`/usr/sbin/ipset list ${SET} | grep -F "packets" | gawk -F" " '{ print $1 }' | ./aggrip -a1 | wc -l`
			if [ "${CLEN}" != "0" ] ; then
				NEWSET="NEW_${SET}"
				NEWSET="${NEWSET:0:32}"
			else
				NEWSET="${SET}"
			fi
				
			INET="inet"
			if [ "${FAM}" == "6" ] ; then
				INET="${INET}6"
			fi

			LEN=`cat ${FILE} | ./aggrip -a1 | wc -l`

			if [ "${LEN}" != "0" ] ; then

				echo "-- Building new set ${NEWSET} with ${LEN} entries from ${FILE} ..."
				echo "-- Current set ${SET} has ${CLEN} entries"

				rm -f ipset.liveupdate.txt
				if [ "${SET}" != "${NEWSET}" ] ; then
					echo "flush ${NEWSET}" > ipset.liveupdate.txt
					echo "destroy ${NEWSET}" >> ipset.liveupdate.txt
				else
					echo "flush ${SET}" > ipset.liveupdate.txt
					echo "destroy ${SET}" >> ipset.liveupdate.txt
				fi
				echo "create ${NEWSET} hash:net family ${INET} hashsize 64 maxelem $(( LEN + 1 )) counters" >> ipset.liveupdate.txt
				gawk -v VAL=${NEWSET} '{ print "add "VAL" " $0" packets 0 bytes 0" }' ${FILE} >> ipset.liveupdate.txt
				if [ "${SET}" != "${NEWSET}" ] ; then
					echo "swap ${NEWSET} ${SET}" >> ipset.liveupdate.txt
					echo "flush ${NEWSET}" >> ipset.liveupdate.txt
					echo "destroy ${NEWSET}" >> ipset.liveupdate.txt
				fi

				echo "-- (Re)Activating set ${SET} (Swap-set: ${NEWSET}) ..."
				cat ipset.liveupdate.txt | /usr/sbin/ipset -! -q restore

				LEN=`/usr/sbin/ipset list ${SET} | grep -F "packets" | gawk -F" " '{ print $1 }' | ./aggrip -a1 | wc -l`

				echo "-- Updated set ${SET} has ${CLEN} entries"
				logger -s -t BLIP-FAST-UPDATE "Updated ipset ${SET} from ${CLEN} to ${LEN} entries ($(( LEN - CLEN )))"
				DATE=`date +"%d-%b-%Y %H:%M:%S"`
				echo "${DATE} Updated ipset ${SET} from ${CLEN} to ${LEN} entries ($(( LEN - CLEN )))" >> live-update.log
			fi
		fi
	done < files.tmp

fi

rm -f update.running

exit 0
