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
cp -R "$XCS_ARCHIVE/Products/Applications/$AppName.app" "$AppArchiveDir/$AppName.app"

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

cd "$XCS_SOURCE_DIR/ShipHub"
BUILD_COMMIT=`git rev-parse HEAD`

GITTMP=`mktemp -d /tmp/git_XXXXX`
echo $GITTMP
pushd .
cd $GITTMP
git clone git+ssh://git@github.com/realartists/shiphub-cocoa.git
cd shiphub-cocoa
git checkout $BUILD_COMMIT

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

DMGTMP=`mktemp -d /tmp/DMGSRC_XXXXX`
mkdir $DMGTMP/Production

echo "$XCS_BOT_NAME $XCS_INTEGRATION_NUMBER" > $DMGTMP/CurrentVersion

cp -R "$AppArchiveDir/$AppName.app.dSYM" "$AppArchiveDir/$AppName.app" $DMGTMP/Production/

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
  -F "notes=`cat $COMMITTMP`" \
  -F "notes_type=1" \
  -H "X-HockeyAppToken: b3bd5a0b7737405c8795d6f9d749e914" \
  https://rink.hockeyapp.net/api/2/apps/upload
popd

# Clean up temporary stuff
rm -r $DMGTMP

# Upload JavaScript Source Maps to Raygun

cd "$XCS_SOURCE_DIR/ShipHub/IssueWeb/dist"

JS_BUILD_ID=`cat BUILD_ID`
SOURCE_MAP_URL_BASE="file:///$JS_BUILD_ID/IssueWeb"

for JSFILE in *.js;
do
    MAPFILE="$JSFILE.map"

    JSURL="$SOURCE_MAP_URL_BASE/$JSFILE"
    MAPURL="$SOURCE_MAP_URL_BASE/$MAPFILE"

    echo "Uploading JS source $JSFILE for URL $JSURL"
    curl \
        -X POST \
        -F "url=$JSURL" \
        -F "file=@$JSFILE" \
        'https://app.raygun.com/upload/jssymbols/yf03ib?authToken=wuIacE9aQxuE8eTJjSDojM8mECOvX7RO'

    echo "Uploading JS source map $MAPFILE for URL $MAPURL"
    curl \
        -X POST \
        -F "url=$MAPURL" \
        -F "file=@$MAPFILE" \
        'https://app.raygun.com/upload/jssymbols/yf03ib?authToken=wuIacE9aQxuE8eTJjSDojM8mECOvX7RO'
done
