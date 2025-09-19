# Get the App Name
if [[ -z "$1" ]]; then
  echo "❌ Usage: $0 <TargetName>"
  exit 1
fi

TARGET_NAME=$1

export ARCHIVE_PATH=$(ls -dt ~/Library/Developer/Xcode/Archives/*/"$TARGET_NAME"*.xcarchive | head -1)
echo "📦 Using Archive Path: $ARCHIVE_PATH"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "❌ Archive not found for target: $TARGET_NAME! Please archive the project first in Xcode."
  exit 1
fi

find "$ARCHIVE_PATH/dSYMs" -name "*.dSYM" | while read line; do
  echo "🔍 Found dsym at: $line"
  dsymuuid=$(dwarfdump -u "$line" | awk '{ print $2 }').dSYM
  echo "⬆️ Uploading dsym to: $dsymuuid"
  # aws s3 cp --recursive "$line" s3://app-archives/ios/$dsymuuid
done
