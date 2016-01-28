#!/bin/bash

# Script to generate delta files for OpenDelta - by Jorrit 'Chainfire' Jongma
# Modified by Christian 'Myself5' Oder to be easier installable and usable.
# Get device either from $DEVICE set by calling script, or first parameter

if [ "$DEVICE" == "" ]; then
	if [ "$1" != "" ]; then
		DEVICE=$1
	fi
fi

if [ "$DEVICE" == "" ]; then
	echo "Abort: no device set" >&2
	stop
fi

# ------ CONFIGURATION ------

HOME=/home/houstonn/storage/tilak/cm/OpenDelta/server/software

BIN_JAVA=java
BIN_MINSIGNAPK=$HOME/files/minsignapk.jar
BIN_XDELTA=$HOME/files/xdelta3
BIN_ZIPADJUST=$HOME/files/zipadjust

FILE_MATCH=cm-*.zip
PATH_CURRENT=$HOME/new
PATH_LAST=$HOME/old

KEY_X509=$HOME/files/platform.x509.pem
KEY_PK8=$HOME/files/platform.pk8

# ------ PROCESS ------
getFileName() {
	echo ${1##*/}
}

getFileNameNoExt() {
	echo ${1%.*}
}

getFileMD5() {
	TEMP=$(md5sum -b $1)
	for T in $TEMP; do echo $T; break; done
}

getFileSize() {
	echo $(stat --print "%s" $1)
}

FILE_CURRENT=$(getFileName $(ls -1 $PATH_CURRENT/$FILE_MATCH))
FILE_LAST=$(getFileName $(ls -1 $PATH_LAST/$FILE_MATCH))
FILE_LAST_BASE=$(getFileNameNoExt $FILE_LAST)

if [ "$FILE_CURRENT" == "" ]; then
	echo "Abort: CURRENT zip not found" >&2
	stop
fi

if [ "$FILE_LAST" == "" ]; then
	echo "Abort: LAST zip not found" >&2
	mkdir -p $PATH_LAST
	cp $PATH_CURRENT/$FILE_CURRENT $PATH_LAST/$FILE_CURRENT
	stop
fi

if [ "$FILE_LAST" == "$FILE_CURRENT" ]; then
	echo "Abort: CURRENT and LAST zip have the same name" >&2
	stop
fi

rm -rf work
mkdir work
rm -rf out
mkdir out

$BIN_ZIPADJUST --decompress $PATH_CURRENT/$FILE_CURRENT work/current.zip
$BIN_ZIPADJUST --decompress $PATH_LAST/$FILE_LAST work/last.zip
$BIN_JAVA -Xmx1024m -jar $BIN_MINSIGNAPK $KEY_X509 $KEY_PK8 work/current.zip work/current_signed.zip
$BIN_JAVA -Xmx1024m -jar $BIN_MINSIGNAPK $KEY_X509 $KEY_PK8 work/last.zip work/last_signed.zip
$BIN_XDELTA -9evfS none -s work/last.zip work/current.zip out/$FILE_LAST_BASE.update
$BIN_XDELTA -9evfS none -s work/current.zip work/current_signed.zip out/$FILE_LAST_BASE.sign

MD5_CURRENT=$(getFileMD5 $PATH_CURRENT/$FILE_CURRENT)
MD5_CURRENT_STORE=$(getFileMD5 work/current.zip)
MD5_CURRENT_STORE_SIGNED=$(getFileMD5 work/current_signed.zip)
MD5_LAST=$(getFileMD5 $PATH_LAST/$FILE_LAST)
MD5_LAST_STORE=$(getFileMD5 work/last.zip)
MD5_LAST_STORE_SIGNED=$(getFileMD5 work/last_signed.zip)
MD5_UPDATE=$(getFileMD5 out/$FILE_LAST_BASE.update)
MD5_SIGN=$(getFileMD5 out/$FILE_LAST_BASE.sign)

SIZE_CURRENT=$(getFileSize $PATH_CURRENT/$FILE_CURRENT)
SIZE_CURRENT_STORE=$(getFileSize work/current.zip)
SIZE_CURRENT_STORE_SIGNED=$(getFileSize work/current_signed.zip)
SIZE_LAST=$(getFileSize $PATH_LAST/$FILE_LAST)
SIZE_LAST_STORE=$(getFileSize work/last.zip)
SIZE_LAST_STORE_SIGNED=$(getFileSize work/last_signed.zip)
SIZE_UPDATE=$(getFileSize out/$FILE_LAST_BASE.update)
SIZE_SIGN=$(getFileSize out/$FILE_LAST_BASE.sign)

DELTA=out/$FILE_LAST_BASE.delta

echo "{" > $DELTA
echo "  \"version\": 1," >> $DELTA
echo "  \"in\": {" >> $DELTA
echo "      \"name\": \"$FILE_LAST\"," >> $DELTA
echo "      \"size_store\": $SIZE_LAST_STORE," >> $DELTA
echo "      \"size_store_signed\": $SIZE_LAST_STORE_SIGNED," >> $DELTA
echo "      \"size_official\": $SIZE_LAST," >> $DELTA
echo "      \"md5_store\": \"$MD5_LAST_STORE\"," >> $DELTA
echo "      \"md5_store_signed\": \"$MD5_LAST_STORE_SIGNED\"," >> $DELTA
echo "      \"md5_official\": \"$MD5_LAST\"" >> $DELTA
echo "  }," >> $DELTA
echo "  \"update\": {" >> $DELTA
echo "      \"name\": \"$FILE_LAST_BASE.update\"," >> $DELTA
echo "      \"size\": $SIZE_UPDATE," >> $DELTA
echo "      \"size_applied\": $SIZE_CURRENT_STORE," >> $DELTA
echo "      \"md5\": \"$MD5_UPDATE\"," >> $DELTA
echo "      \"md5_applied\": \"$MD5_CURRENT_STORE\"" >> $DELTA
echo "  }," >> $DELTA
echo "  \"signature\": {" >> $DELTA
echo "      \"name\": \"$FILE_LAST_BASE.sign\"," >> $DELTA
echo "      \"size\": $SIZE_SIGN," >> $DELTA
echo "      \"size_applied\": $SIZE_CURRENT_STORE_SIGNED," >> $DELTA
echo "      \"md5\": \"$MD5_SIGN\"," >> $DELTA
echo "      \"md5_applied\": \"$MD5_CURRENT_STORE_SIGNED\"" >> $DELTA
echo "  }," >> $DELTA
echo "  \"out\": {" >> $DELTA
echo "      \"name\": \"$FILE_CURRENT\"," >> $DELTA
echo "      \"size_store\": $SIZE_CURRENT_STORE," >> $DELTA
echo "      \"size_store_signed\": $SIZE_CURRENT_STORE_SIGNED," >> $DELTA
echo "      \"size_official\": $SIZE_CURRENT," >> $DELTA
echo "      \"md5_store\": \"$MD5_CURRENT_STORE\"," >> $DELTA
echo "      \"md5_store_signed\": \"$MD5_CURRENT_STORE_SIGNED\"," >> $DELTA
echo "      \"md5_official\": \"$MD5_CURRENT\"" >> $DELTA
echo "  }" >> $DELTA
echo "}" >> $DELTA

mkdir publish >/dev/null 2>/dev/null
mkdir publish/$DEVICE >/dev/null 2>/dev/null
cp out/* publish/$DEVICE/.

rm -rf work
rm -rf out

rm -rf $PATH_LAST
mkdir -p $PATH_LAST
cp $PATH_CURRENT/$FILE_CURRENT $PATH_LAST/$FILE_CURRENT
rm -rf $PATH_CURRENT
mkdir -p $PATH_CURRENT
