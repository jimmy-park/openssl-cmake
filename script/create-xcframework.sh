#!/bin/bash

IOS_PRESET="ios"
SIM_PRESET="ios_sim"
MAC_PRESET="macos"
OUTPUT="install/OpenSSL.xcframework"
LIBS=""

set -e

for preset in $IOS_PRESET $SIM_PRESET $MAC_PRESET; do
    INSTALL_DIR="install/$preset"

    rm -rf $INSTALL_DIR
    cmake --preset $preset -DOPENSSL_CONFIGURE_OPTIONS="--prefix=$(pwd)/$INSTALL_DIR"
    cmake --build --preset $preset -t install
    libtool -static -o $INSTALL_DIR/lib/openssl.a \
        $INSTALL_DIR/lib/libcrypto.a \
        $INSTALL_DIR/lib/libssl.a
    LIBS="$LIBS -library $INSTALL_DIR/lib/openssl.a -headers $INSTALL_DIR/include"
done

rm -rf $OUTPUT
xcodebuild -create-xcframework $LIBS -output $OUTPUT
