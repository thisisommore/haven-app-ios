# Building the macOS Release DMG

Produces `iOS/build/dist/haven-macos-arm64.dmg`: arm64-only Release build,
Developer ID signed, notarized and stapled (both the app and the DMG).

All commands run from the **repository root**.

## Prerequisites (one-time setup)

1. **Developer ID Application certificate** in your login keychain
   (Apple Developer account → Certificates → Developer ID Application).
2. **Notary credentials** stored in the keychain under the profile name
   `haven-notary` (uses an app-specific password from
   https://appleid.apple.com):

   ```bash
   xcrun notarytool store-credentials haven-notary \
     --apple-id <your-apple-id-email> --team-id NNJNNZZKNN
   ```

3. `iOS/build/dist/ExportOptions.plist` (already in the repo layout):
   method `developer-id`, teamID `NNJNNZZKNN`.

## Build steps

### 1. Archive (Release, arm64-only)

```bash
rm -rf iOS/build/haven.xcarchive iOS/build/dist/export
xcodebuild archive \
  -project iOS/iOSExample.xcodeproj \
  -scheme mac \
  -configuration Release \
  -archivePath iOS/build/haven.xcarchive \
  ARCHS=arm64
```

> Drop `ARCHS=arm64` for a universal (arm64 + x86_64) build — roughly
> doubles the DMG size.

### 2. Export with Developer ID signing

```bash
xcodebuild -exportArchive \
  -archivePath iOS/build/haven.xcarchive \
  -exportPath iOS/build/dist/export \
  -exportOptionsPlist iOS/build/dist/ExportOptions.plist
```

### 3. Notarize and staple the app

```bash
cd iOS/build/dist/export
ditto -c -k --keepParent haven.app haven.zip
xcrun notarytool submit haven.zip --keychain-profile haven-notary --wait
xcrun stapler staple haven.app
cd -
```

> If the upload times out (`deadlineExceeded` / "appears to be offline"),
> just rerun `notarytool submit` — it is transient Apple-side flakiness.

### 4. Rebuild the DMG

```bash
cd iOS/build/dist
rm -rf staging/haven.app
cp -R export/haven.app staging/
hdiutil create -volname Haven -srcfolder staging -ov -format UDZO haven-macos-arm64.dmg
cd -
```

(`staging/` already contains the `Applications` symlink.)

### 5. Sign, notarize and staple the DMG

```bash
cd iOS/build/dist
codesign --force --sign "Developer ID Application: Om More (NNJNNZZKNN)" \
  --timestamp haven-macos-arm64.dmg
xcrun notarytool submit haven-macos-arm64.dmg --keychain-profile haven-notary --wait
xcrun stapler staple haven-macos-arm64.dmg
cd -
```

## Verify

```bash
# Gatekeeper assessment of the DMG
spctl -a -vv -t open --context context:primary-signature \
  iOS/build/dist/haven-macos-arm64.dmg
# → accepted, source=Notarized Developer ID

# Stapled ticket on the DMG
xcrun stapler validate iOS/build/dist/haven-macos-arm64.dmg

# App inside: mount and check
hdiutil attach -nobrowse -readonly -mountpoint /tmp/haven_verify \
  iOS/build/dist/haven-macos-arm64.dmg
spctl -a -vv /tmp/haven_verify/haven.app
xcrun stapler validate /tmp/haven_verify/haven.app
file /tmp/haven_verify/haven.app/Contents/MacOS/haven          # thin arm64
/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" \
  /tmp/haven_verify/haven.app/Contents/Info.plist               # e.g. 26.0
hdiutil detach /tmp/haven_verify
```

## Notes

- Minimum macOS version is set by `MACOSX_DEPLOYMENT_TARGET` on the `mac`
  target in `iOS/iOSExample.xcodeproj` (currently 26.0).
- Debug builds use `ONLY_ACTIVE_ARCH=YES`, so they are always arm64-only on
  Apple Silicon and are signed with the Apple Development certificate — do
  not distribute those.
