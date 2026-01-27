#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CaptureThis"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-artifacts}"

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "App not found at ${APP_PATH}" >&2
  exit 1
fi

mkdir -p "${ARTIFACTS_DIR}"

ZIP_PATH="${ARTIFACTS_DIR}/${APP_NAME}.app.zip"
rm -f "${ZIP_PATH}"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

DMG_STAGING="${ARTIFACTS_DIR}/dmg"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_PATH}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

DMG_PATH="${ARTIFACTS_DIR}/${APP_NAME}.dmg"
rm -f "${DMG_PATH}"
/usr/bin/hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${DMG_PATH}"

rm -rf "${DMG_STAGING}"

echo "Created ${ZIP_PATH}"
echo "Created ${DMG_PATH}"
