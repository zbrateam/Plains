#!/bin/bash

set -e
cd "$(dirname "$0")"

if [[ -f apt/build/CMakeCache.txt && -f apt/build/include/config.h ]]; then
	printf 'Nothing to do.\n'
	exit 0
fi

printf 'warning: Generating apt build…\n' >&2
git submodule update --init --recursive
cd apt

DEVELOPER_DIR="$(xcode-select -p)"
SDKROOT="$(xcrun -sdk iphoneos -show-sdk-path)"

export PATH=$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin:/opt/procursus/bin:/opt/procursus/sbin:/opt/procursus/games:/opt/homebrew/bin:/opt/homebrew/sbin:/opt/homebrew/games:$PATH
export CPATH=$CPATH:/opt/procursus/include:/opt/homebrew/include
export LIBRARY_PATH=$LIBRARY_PATH:/opt/procursus/lib:/opt/homebrew/lib

aptinstall=()
brewinstall=()

if ! command -v cmake >/dev/null; then
	aptinstall+=(cmake)
	brewinstall+=(cmake)
fi

if ! command -v gettext >/dev/null; then
	aptinstall+=(libintl-dev)
	brewinstall+=(gettext)
fi

if ! pkg-config gnutls; then
	aptinstall+=(libgnutls28-dev)
	brewinstall+=(gnutls)
fi

if ! pkg-config liblz4; then
	aptinstall+=(liblz4-dev)
	brewinstall+=(lz4)
fi

if ! pkg-config libzstd; then
	aptinstall+=(libzstd-dev)
	brewinstall+=(zstd)
fi

if ! command -v libgcrypt-config >/dev/null; then
	aptinstall+=(libgcrypt20-dev)
	brewinstall+=(libgcrypt)
fi

if ! pkg-config gpg-error; then
	aptinstall+=(libgpg-error-dev)
	brewinstall+=(libgpg-error)
fi

if ! pkg-config libxxhash; then
	aptinstall+=(libxxhash-dev)
	brewinstall+=(xxhash)
fi

if [[ ${#aptinstall[@]} -gt 0 ]]; then
	printf 'error: %s dependencies missing. Run:\nerror:   sudo apt install %s\nerror: or\nerror:   brew install %s\nerror: and then try rebuilding\n' "${#aptinstall[@]}" "${aptinstall[*]}" "${brewinstall[*]}" >&2
	exit 1
fi

for i in ../apt-patches/*.diff; do
	patchname=$(basename $i)
	if [[ ! -f $patchname.done ]]; then
		printf 'Applying %s\n' $patchname
		patch -sN -d . -p1 < $i >/dev/null
		touch $patchname.done
	fi
done

rm -rf build
mkdir build
cd build
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
	-DTRIEHASH_EXECUTABLE="$PWD"/../../triehash/triehash.pl \
	-DDPKG_DATADIR=/usr/share/dpkg \
	-DBERKELEY_LIBRARIES=-ldb \
	-DBERKELEY_INCLUDE_DIRS="$SDKROOT"/usr/include \
	..
