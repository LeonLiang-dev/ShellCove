APP_NAME := ShellCove
# 与 SwiftPM 的 .build 分开，避免两套构建产物互相覆盖
DERIVED := .xcodebuild

# Homebrew 安装失败时，XcodeGen 也可以放在 ~/.local/bin
XCODEGEN ?= $(shell command -v xcodegen 2>/dev/null || echo $(HOME)/.local/bin/xcodegen)
XCODEBUILD := xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Debug -derivedDataPath $(DERIVED)
NO_SIGN := CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

.PHONY: all gen build run test clean

all: build

gen:
	@$(XCODEGEN) generate --quiet

build: gen
	@$(XCODEBUILD) $(NO_SIGN) build

run: build
	@open $(DERIVED)/Build/Products/Debug/$(APP_NAME).app

test: gen
	@$(XCODEBUILD) $(NO_SIGN) test

clean:
	@rm -rf $(DERIVED) $(APP_NAME).xcodeproj
