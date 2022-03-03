#!/bin/bash

set -e

git submodule update --init --recursive apt
cd apt

for i in ../apt-patches/*.diff; do
	patchname=$(basename $i)
	if [[ ! -f $patchname.done ]]; then
		printf 'Applying %s\n' $patchname
		patch -sN -d . -p1 < $i
		touch $patchname.done
	fi
done

cmake . \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_CROSSCOMPILING=true \
	-DCMAKE_SYSTEM_NAME=Darwin \
	-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
	-DCMAKE_OSX_ARCHITECTURES=arm64 \
	-DROOT_GROUP=wheel \
	-DCURRENT_VENDOR=procursus \
	-DCOMMON_ARCH=darwin-arm64 \
	-DUSE_NLS=1 \
	-DWITH_DOC=0 \
	-DWITH_TESTS=0 \
	-DDOCBOOK_XSL=/dev/null
