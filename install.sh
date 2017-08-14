#!/bin/sh
set -e

JAVA_VER=7

rm -f /tmp/oab-index.html /tmp/oab-download.html >/dev/null 2>&1 || true
trap "rm -f /tmp/oab-index.html /tmp/oab-download.html" EXIT ERR QUIT INT TERM

# Try and dynamic find the JDK downloads
echo " [x] Getting Java SE download page "
curl -sL "http://www.oracle.com/technetwork/java/javase/downloads/index.html" -o /tmp/oab-index.html

# See if the Java version is on the download frontpage, otherwise look for it in
# the previous releases page.
DOWNLOAD_INDEX=`grep -P -o "/technetwork/java/javase/downloads/jdk${JAVA_VER}u\d+-downloads-\d+\.html" /tmp/oab-index.html | uniq`
JAVA_UPD=`echo ${DOWNLOAD_INDEX} | sed 's/.*u//;s/-d.*$//'`
if [ -z "${JAVA_UPD}" ] || ! echo "${JAVA_UPD}" | grep -q "[0-9][0-9]*"; then
    echo
    echo "Could not retrieve the latest known JDK update version." >&2
    echo
    exit 1
fi

if [ ! "$1" = '-f' ] && which javac >/dev/null 2>&1 && javac -version 2>&1 | grep -qs "^javac 1\.${JAVA_VER}[0-9_.]*${JAVA_UPD}$"
then
    echo
    echo "Latest JDK${JAVA_VER}u${JAVA_UPD} is already installed" >&2
    echo
    echo "Rerun this command with -f to force reinstallation."
    echo
    exit 1
fi

if [ -n "${DOWNLOAD_INDEX}" ]; then
    echo " [x] Getting current release download page "
    curl -sL http://www.oracle.com/${DOWNLOAD_INDEX} -o /tmp/oab-download.html
else
    echo
    echo "Could not find a suitable download for JDK 7u${JAVA_UPD}."
    exit 1
fi

# Set the files we're downloading since sun-java6 and oracle-java7 differ.
JAVA_BINS="jdk-${JAVA_VER}u${JAVA_UPD}-macosx-x64.dmg"


for JAVA_BIN in ${JAVA_BINS}
do
    # Get the download URL and size
    DOWNLOAD_URL=`grep ${JAVA_BIN} /tmp/oab-download.html | cut -d'{' -f2 | cut -d',' -f3 | cut -d'"' -f4`
    DOWNLOAD_SIZE=`grep ${JAVA_BIN} /tmp/oab-download.html | cut -d'{' -f2 | cut -d',' -f2 | cut -d':' -f2 | sed 's/"//g'`
    # Cookies required for download
    COOKIES="oraclelicensejdk-${JAVA_VER}u${JAVA_UPD}-oth-JPR=accept-securebackup-cookie;gpw_e24=http://edelivery.oracle.com"

    echo " [x] Downloading ${JAVA_BIN} : ${DOWNLOAD_SIZE} "
    curl -L -b "${COOKIES}" -L "${DOWNLOAD_URL}" -o "/tmp/${JAVA_BIN}"
    trap "rm -f \"/tmp/${JAVA_BIN}\" /tmp/oab-index.html /tmp/oab-download.html" EXIT ERR QUIT INT TERM
    VOLUME="`hdiutil attach /tmp/jdk-7u7-macosx-x64.dmg | awk '/dev.*Apple_HFS/{print substr($0,index($0,$3))}'`"
    trap "cd /;hdiutil detach \"${VOLUME}\";rm -f \"/tmp/${JAVA_BIN}\" /tmp/oab-index.html /tmp/oab-download.html>/dev/null" EXIT ERR QUIT INT TERM
    echo " [x] Waiting for image to properly mount"
    sleep 3
    (cd "${VOLUME}" && sudo installer -pkg *.pkg -target / )
    echo " [x] Waiting for install to finish completely"
    sleep 3
    hdiutil detach "${VOLUME}" >/dev/null
    echo " [x] Waiting for image to dismount"
    sleep 2
    rm -f "/tmp/${JAVA_BIN}"
    trap "rm -f /tmp/oab-index.html /tmp/oab-download.html" EXIT ERR QUIT INT TERM
done
