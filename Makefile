APP_NAME := ShellCove
# 与 SwiftPM 的 .build 分开，避免两套构建产物互相覆盖
DERIVED := .xcodebuild

# Homebrew 安装失败时，XcodeGen 也可以放在 ~/.local/bin
XCODEGEN ?= $(shell command -v xcodegen 2>/dev/null || echo $(HOME)/.local/bin/xcodegen)
XCODEBUILD := xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug -derivedDataPath $(DERIVED) -skipPackagePluginValidation -skipMacroValidation
NO_SIGN := CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

.PHONY: all gen build run run-swift test clean

all: build

gen:
	@$(XCODEGEN) generate --quiet

build: gen
	@$(XCODEBUILD) $(NO_SIGN) build

run: build
	@open $(DERIVED)/Build/Products/Debug/$(APP_NAME).app

# 不依赖 xcodebuild 的备用启动方式：SwiftPM 构建后直接运行。
# 适合 Xcode 首次启动组件异常、暂时无法修复时使用。
run-swift:
	@swift build
	@./.build/debug/$(APP_NAME)

test: gen
	@$(XCODEBUILD) $(NO_SIGN) test

clean:
	@rm -rf $(DERIVED) $(APP_NAME).xcodeproj

# ==== 发布流水线（PRD M5：签名 → 公证 → 打包）====
# 与 project.yml 的 MARKETING_VERSION 保持同步；这里只用于产物文件名。
VERSION := 1.0.0
# 使用前填入 Apple Developer 信息（或通过命令行传入）：
#   make release TEAM=XXXXXXXXXX IDENTITY="Developer ID Application: 你的名字 (XXXXXXXXXX)"
TEAM ?=
IDENTITY ?=
NOTARY_PROFILE ?= shellcove-notary

XCODEBUILD_RELEASE := xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) \
    -configuration Release -derivedDataPath $(DERIVED) \
    -skipPackagePluginValidation -skipMacroValidation
RELEASE_APP := $(DERIVED)/Build/Products/Release/$(APP_NAME).app

.PHONY: release notarize dmg

# 一次性准备（手工执行，不进 Makefile）：
#   xcrun notarytool store-credentials shellcove-notary \
#     --apple-id <AppleID> --team-id <TEAM_ID> --password <应用专用密码>

release: gen
	@test -n "$(TEAM)" && test -n "$(IDENTITY)" || { \
		echo "错误：请先设置 TEAM 与 IDENTITY（Apple Developer 信息），参见 Makefile 注释。"; exit 1; }
	@$(XCODEBUILD_RELEASE) CODE_SIGN_STYLE=Manual \
	    DEVELOPMENT_TEAM=$(TEAM) "CODE_SIGN_IDENTITY=$(IDENTITY)" build
	@codesign --verify --deep --strict --verbose=2 "$(RELEASE_APP)"

# 关键顺序：notarytool 提交的是 staple 前的 zip；staple 后必须重打最终分发 zip，
# 最终包里才携带离线可验的 ticket。
notarize: release
	@ditto -c -k --keepParent "$(RELEASE_APP)" "$(APP_NAME)-notary.zip"
	@xcrun notarytool submit "$(APP_NAME)-notary.zip" --keychain-profile $(NOTARY_PROFILE) --wait
	@xcrun stapler staple "$(RELEASE_APP)"
	@xcrun stapler validate "$(RELEASE_APP)"
	@rm -rf dist && mkdir dist && cp -R "$(RELEASE_APP)" dist/
	@cd dist && ditto -c -k --keepParent $(APP_NAME).app "$(APP_NAME)-$(VERSION).zip"

dmg: notarize
	@hdiutil create -volname "$(APP_NAME)" -srcfolder "dist/$(APP_NAME).app" \
	    -ov -format UDZO "dist/$(APP_NAME)-$(VERSION).dmg"

# ==== 免账号分发（PRD R1：本地自用与开发者分发）====
# 无 Apple Developer 账号时使用：Release 构建 + ad-hoc 签名 + 拖拽式 DMG。
# 产物在其他 Mac 上首次打开需「右键 → 打开」放行一次，之后不再提示；
# 消除警告仍需走 release/notarize 流程。
.PHONY: package

package: gen
	@$(XCODEBUILD_RELEASE) $(NO_SIGN) build
	@codesign --force --deep --sign - \
	    --entitlements $(APP_NAME)/$(APP_NAME).entitlements \
	    --options runtime "$(RELEASE_APP)"
	@codesign --verify --deep --strict "$(RELEASE_APP)"
	@rm -rf dist && mkdir dist
	@cp -R "$(RELEASE_APP)" dist/
	@ln -s /Applications dist/Applications
	@hdiutil create -volname "$(APP_NAME)" -srcfolder dist \
	    -ov -format UDZO "$(APP_NAME)-$(VERSION).dmg"
	@rm dist/Applications
	@echo "完成：$(APP_NAME)-$(VERSION).dmg（ad-hoc 签名，免账号分发）"
