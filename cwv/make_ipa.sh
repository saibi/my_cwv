#!/bin/sh
# 무서명 IPA를 만든다. SideStore가 설치할 때 다시 서명한다.
set -e
cd "$(dirname "$0")/.."
xcodebuild -project cwv/CWV.xcodeproj -scheme CWV -configuration Release \
  -sdk iphoneos -derivedDataPath build/ipa CODE_SIGNING_ALLOWED=NO build
rm -rf build/Payload build/CWV.ipa
mkdir -p build/Payload
cp -R build/ipa/Build/Products/Release-iphoneos/CWV.app build/Payload/
(cd build && zip -qr CWV.ipa Payload)
echo "build/CWV.ipa"
