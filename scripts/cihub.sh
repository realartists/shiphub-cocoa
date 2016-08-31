CodesignIdentity="Developer ID Application: Real Artists, Inc."
# TeamIdentifier=`security find-identity | grep "$CodesignIdentity" | tail -1 | perl -pe 's/.*\((.*?)\).*/$1/'`
DSYMName=Ship.app.dSYM
AppName=Ship
AppArchiveDir="/Users/Shared/ShipBuilds/$XCS_BOT_NAME/$XCS_INTEGRATION_NUMBER"

echo "AppArchiveDir is $AppArchiveDir"

mkdir -p $AppArchiveDir

cd "$XCS_OUTPUT_DIR"
pwd

echo "Exporting .app"
xcodebuild -exportArchive -exportFormat APP -archivePath "$XCS_ARCHIVE" -exportPath "$AppArchiveDir/$AppName"

echo "Setting CFBundleVersion"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion \"$XCS_INTEGRATION_NUMBER\"" "$AppArchiveDir/$AppName.app/Contents/Info.plist"

echo "Resigning app with Developer ID"
codesign -vvvv --deep -f -s "$CodesignIdentity" "$AppArchiveDir/$AppName.app"

echo "Copying archive"
cp -R "$XCS_ARCHIVE" "$AppArchiveDir/"

echo "Copying symbol files"
cp -R "$XCS_ARCHIVE/dSYMs/$DSYMName" "$AppArchiveDir/$AppName.app.dSYM"

echo "Updating latest symlink"
cd `dirname "$AppArchiveDir"`

SymlinkPath=Latest
echo rm -f $SymlinkPath
echo ln -s $XCS_INTEGRATION_NUMBER $SymlinkPath

rm -f $SymlinkPath
ln -s $XCS_INTEGRATION_NUMBER $SymlinkPath

GITTMP=`mktemp -d /tmp/git_XXXXX`
echo $GITTMP
pushd .
cd $GITTMP
git clone git+ssh://git@github.com/realartists/shiphub-cocoa.git
cd shiphub-cocoa

pwd

TAG_LATEST="${XCS_BOT_NAME}-Latest"
TAG_CURRENT="${XCS_BOT_NAME}-${XCS_INTEGRATION_NUMBER}"

echo "Latest tag is $TAG_LATEST and current tag is $TAG_CURRENT"

git config user.name "James Howard"
git config user.email "jameshoward@mac.com"

git fetch --tags

git tag -a "$TAG_CURRENT" -m "Tagging for CI build"

COMMITTMP=`mktemp /tmp/commitlog_XXXXX`

# Grab the commit log since our last build
git log $TAG_LATEST..$TAG_CURRENT > $COMMITTMP

# Delete the old latest tag
git push origin ":refs/tags/$TAG_LATEST"
# Recreate the new latest tag
git tag -fa "$TAG_LATEST" -m "Tagging for CI build"
# Push all the tags to remote
git push origin master --tags

popd

# Clean up temporary git checkout
rm -rf $GITTMP

echo "Creating disk images for dropbox upload"
DMGTMP=`mktemp -d /tmp/DMGSRC_XXXXX`
mkdir $DMGTMP/Production

echo "$XCS_BOT_NAME $XCS_INTEGRATION_NUMBER" > $DMGTMP/CurrentVersion

cp -R "$AppArchiveDir/$AppName.app.dSYM" "$AppArchiveDir/$AppName.app" $DMGTMP/Production/

hdiutil create $DMGTMP/Production.dmg -srcdir $DMGTMP/Production

echo "Copying to Amium"
/usr/local/bin/xpcdropboxclient $DMGTMP/CurrentVersion
/usr/local/bin/xpcdropboxclient $DMGTMP/Production.dmg

echo "Uploading to Dropbox"
# change HOME in order to trick dropbox_uploader into not trying to do its setup thing again (-f doesn't seem to work)
OLDHOME="$HOME"
export HOME=/Library/Developer/XcodeServer
/Library/Developer/XcodeServer/dropbox_uploader.sh upload $DMGTMP/Production.dmg "ShipHubBuilds/Mac/Production.dmg"
/Library/Developer/XcodeServer/dropbox_uploader.sh upload $DMGTMP/CurrentVersion "ShipHubBuilds/Mac/CurrentVersion"
echo "Done uploading to Dropbox"
export HOME="$OLDHOME"

echo "Uploading to HockeyApp"
pushd .
cd $DMGTMP/Production
ditto -c -k --sequesterRsrc --keepParent "$AppName.app" "$AppName.app.zip"
ditto -c -k --sequesterRsrc --keepParent "$AppName.app.dSYM" "$AppName.app.dSYM.zip"
curl \
  -F "release_type=3" \
  -F "status=2" \
  -F "ipa=@$AppName.app.zip" \
  -F "dsym=@$AppName.app.dSYM.zip" \
  -F "notes=@$COMMITTMP" \
  -H "X-HockeyAppToken: b3bd5a0b7737405c8795d6f9d749e914" \
  https://rink.hockeyapp.net/api/2/apps/upload
popd

# Clean up temporary dmg stuff
rm -r $DMGTMP


