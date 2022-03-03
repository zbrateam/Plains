#!/bin/bash

set -e

cd ..
PROCURSUS_ROOT=$(cd ../../../../../../git/procursus; pwd)

rm -rf stage Vendor/apt-pkg-deps
mkdir -p stage Vendor/apt-pkg-deps

for file in libgcrypt.a libgpg-error.a libintl.a liblz4.a libxxhash.a libzstd.a; do
	filebase=${file/.a}
	printf '\nExtracting %s\n' "$file"

	for arch in darwin-amd64 darwin-arm64 iphoneos-arm64; do
		case $arch in
			darwin-amd64 | darwin-arm64)
				cfver=1700
				prefix=/opt/procursus
				;;
			iphoneos-arm64)
				cfver=1600
				prefix=/usr
				;;
		esac

		mkdir -p stage/$arch/$filebase
		cd stage/$arch/$filebase
		xcrun ar -x $PROCURSUS_ROOT/build_base/$arch/$cfver/$prefix/lib/$file
		cd ../../..
	done

	for os in macos maccatalyst ios iossim; do
		case $os in
			macos)
				archs=(darwin-amd64 darwin-arm64)
				sdk=macosx
				version=11.0
				;;
			maccatalyst)
				archs=(darwin-amd64 darwin-arm64)
				version=14.2
				sdk=iphoneos
				;;
			ios)
				archs=(iphoneos-arm64)
				version=13.0
				sdk=iphoneos
				;;
			iossim)
				archs=(darwin-amd64 darwin-arm64)
				version=13.0
				sdk=iphonesimulator
				;;
		esac

		for arch in "${archs[@]}"; do
			printf 'Processing %s for %s:%s\n' "$file" "$os" "$arch"

			case $arch in
				*-arm64)
					archname=arm64
					;;
				*-amd64)
					archname=x86_64
					;;
			esac

			mkdir -p stage/apt-pkg-deps/$os/$filebase/$arch

			for obj in stage/$arch/$filebase/*.o; do
				xcrun vtool \
					-set-build-version $os $version $version \
					-replace \
					-output stage/apt-pkg-deps/$os/$filebase/$arch/$(basename ${obj/.o}).o \
					$obj
			done

			xcrun -sdk $sdk libtool \
				-static \
				-arch_only $archname \
				-o stage/apt-pkg-deps/$os/$filebase-$arch.a \
				stage/apt-pkg-deps/$os/$filebase/$arch/*.o
		done

		lipo \
			-create \
			stage/apt-pkg-deps/$os/$filebase-*.a \
			-o stage/apt-pkg-deps/$filebase-$os.a
	done

	printf 'Generating %s.xcframework\n' "$filebase"

	# Patch symbols that won’t be resolved under iossim SDK
	perl -pi -e 's/opendir\$INODE64/opendir\x00\x00\x00\x00\x00\x00\x00\x00/g' stage/apt-pkg-deps/$filebase-iossim.a
	perl -pi -e 's/readdir\$INODE64/readdir\x00\x00\x00\x00\x00\x00\x00\x00/g' stage/apt-pkg-deps/$filebase-iossim.a
	perl -pi -e 's/syslog\$DARWIN_EXTSN/syslog\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00/g' stage/apt-pkg-deps/$filebase-iossim.a
	
	xcodebuild -create-xcframework \
		-library stage/apt-pkg-deps/$filebase-macos.a \
		-library stage/apt-pkg-deps/$filebase-maccatalyst.a \
		-library stage/apt-pkg-deps/$filebase-ios.a \
		-library stage/apt-pkg-deps/$filebase-iossim.a \
		-output Vendor/apt-pkg-deps/$filebase.xcframework
done

# Build dummy libiosexec
cp $PROCURSUS_ROOT/build_stage/iphoneos-arm64/1600/libiosexec/usr/lib/libiosexec.a stage/apt-pkg-deps/libiosexec-ios.a

for arch in x86_64 arm64; do
	xcrun -sdk iphonesimulator \
		clang \
		-target $arch-apple-ios13.0-simulator \
		-c \
		-o stage/apt-pkg-deps/libiosexec-dummy-$arch.o \
		Vendor/libiosexec/libiosexec-dummy.c
	xcrun -sdk iphonesimulator \
		libtool \
		-static \
		-arch_only $arch \
		-o stage/apt-pkg-deps/libiosexec-dummy-$arch.a \
		stage/apt-pkg-deps/libiosexec-dummy-$arch.o
done

lipo \
	-create \
	stage/apt-pkg-deps/libiosexec-dummy-*.a \
	-o stage/apt-pkg-deps/libiosexec-iossim.a

xcodebuild -create-xcframework \
	-library stage/apt-pkg-deps/libiosexec-ios.a \
	-library stage/apt-pkg-deps/libiosexec-iossim.a \
	-output Vendor/apt-pkg-deps/libiosexec.xcframework

rm -rf stage
