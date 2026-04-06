VERSION ?= 1.0.0
APP     = Screeny
SCHEME  = Screeny
BUILD_DIR = build

.PHONY: build dmg clean

build:
	xcodebuild \
		-project $(APP).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

dmg: build
	hdiutil create \
		-volname "$(APP)" \
		-srcfolder "$(BUILD_DIR)/Build/Products/Release/$(APP).app" \
		-ov \
		-format UDZO \
		"$(APP)-$(VERSION).dmg"

clean:
	rm -rf $(BUILD_DIR) $(APP)-*.dmg
