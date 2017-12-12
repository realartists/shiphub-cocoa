CodesignIdentity="3rd Party Mac Developer Application: Real Artists, Inc. (EL9BUK3ZCV)"
DevelopmentCodesignIdentity="Mac Developer: James Howard (68U3WG7JF9)"
ProvisioningProfile="Reviewed By Me - Production"
DevelopmentProvisioningProfile="James - Reviewed By Me - Mac Development"
# TeamIdentifier=`security find-identity | grep "$CodesignIdentity" | tail -1 | perl -pe 's/.*\((.*?)\).*/$1/'`
DSYMName="Reviewed By Me.app.dSYM"
AppName="Reviewed By Me"
AppArchiveDir="/Users/Shared/ShipBuilds/$XCS_BOT_NAME/$XCS_INTEGRATION_NUMBER/Reviewed By Me"

echo "AppArchiveDir is $AppArchiveDir"

mkdir -p "$AppArchiveDir"
mkdir -p "$AppArchiveDir/Store"
mkdir -p "$AppArchiveDir/Development"

cd "$XCS_OUTPUT_DIR"
pwd

echo "Setting CFBundleVersion"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion \"$XCS_INTEGRATION_NUMBER\"" "$XCS_ARCHIVE/Products/Applications/$AppName.app/Contents/Info.plist"

echo "Exporting Development Signed App"

cat >/tmp/exportOptions.plist <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>development</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.realartists.Reviewed-By-Me</key>
		<string>James - Reviewed By Me - Mac Development</string>
	</dict>
	<key>signingCertificate</key>
	<string>Mac Developer</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>teamID</key>
	<string>EL9BUK3ZCV</string>
</dict>
</plist>
EOL

xcodebuild -exportArchive -exportOptionsPlist /tmp/exportOptions.plist -archivePath "$XCS_ARCHIVE" -exportPath "$AppArchiveDir/Development"

echo "Exporting Production Signed Installer for App Store"

cat >/tmp/exportOptions.plist <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>development</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.realartists.Reviewed-By-Me</key>
		<string>James - Reviewed By Me - Mac Development</string>
	</dict>
	<key>signingCertificate</key>
	<string>Mac Developer</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>teamID</key>
	<string>EL9BUK3ZCV</string>
</dict>
</plist>
EOL

xcodebuild -exportArchive -exportOptionsPlist /tmp/exportOptions.plist -archivePath "$XCS_ARCHIVE" -exportPath "$AppArchiveDir/Store"

echo "Copying symbol files"
cp -R "$XCS_ARCHIVE/dSYMs/$DSYMName" "$AppArchiveDir/$AppName.app.dSYM"

DMGTMP=`mktemp -d /tmp/DMGSRC_XXXXX`
mkdir $DMGTMP/Development

echo "$XCS_BOT_NAME $XCS_INTEGRATION_NUMBER" > $DMGTMP/CurrentVersion

cp -R "$AppArchiveDir/Development/$AppName.app.dSYM" "$AppArchiveDir/$AppName.app" $DMGTMP/Development/

echo "Uploading to HockeyApp"
pushd .
cd $DMGTMP/Development
ditto -c -k --sequesterRsrc --keepParent "$AppName.app" "$AppName.app.zip"
ditto -c -k --sequesterRsrc --keepParent "$AppName.app.dSYM" "$AppName.app.dSYM.zip"
curl \
-F "release_type=1" \
-F "status=1" \
-F "ipa=@$AppName.app.zip" \
-F "dsym=@$AppName.app.dSYM.zip" \
-H "X-HockeyAppToken: b3bd5a0b7737405c8795d6f9d749e914" \
https://rink.hockeyapp.net/api/2/apps/upload
popd

# Clean up temporary stuff
rm -r $DMGTMP

