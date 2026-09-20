SIM := platform=iOS Simulator,name=iPhone 14
APP := $(wildcard ~/Library/Developer/Xcode/DerivedData/Steady-*/Build/Products/Debug-iphonesimulator/Steady.app)
export PATH := $(HOME)/.maestro/maestro/bin:$(PATH)
export MAESTRO_CLI_NO_ANALYTICS := 1

.PHONY: build test e2e

build:
	xcodebuild -project Steady.xcodeproj -scheme Steady -destination '$(SIM)' -configuration Debug build

test:
	xcodebuild -project Steady.xcodeproj -scheme Steady -destination '$(SIM)' test

# E2E（Maestro，只跑模拟器）：构建 → 装进 booted 模拟器 → e2e_run.sh 顺序跑全部旅程
# 三级结果 PASS/FAILED/CRASHED，崩溃哨兵见 tools/e2e_run.sh（exit 2=有 crash）
e2e: build
	xcrun simctl install booted $(APP)
	tools/e2e_run.sh
