#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building AiCash...${NC}"

# Build the app
xcodebuild \
  -scheme AiCash \
  -configuration Release \
  -derivedDataPath build \
  -destination 'platform=macOS' \
  clean build

# Find the built app
APP_PATH=$(find build -name "AiCash.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
  echo -e "${RED}Error: Could not find built app${NC}"
  exit 1
fi

echo -e "${GREEN}App built at: $APP_PATH${NC}"

# Get version from tag or use default
VERSION=${1:-"dev"}
DMG_NAME="AiCash-${VERSION}.dmg"

echo -e "${GREEN}Creating DMG: $DMG_NAME${NC}"

# Create temporary directory
TMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$TMP_DIR/"

# Create Applications symlink for easy installation
ln -s /Applications "$TMP_DIR/Applications"

# Create installation guide
cat > "$TMP_DIR/安装指南.md" << 'EOF'
# AiCash 安装指南

## 安装步骤

1. 将 **AiCash.app** 拖拽到 **Applications** 文件夹

2. 首次运行时，由于应用未签名，需要执行以下命令解除隔离：

```bash
sudo xattr -r -d com.apple.quarantine /Applications/AiCash.app
```

或者右键点击 AiCash.app，选择「打开」，然后在弹出的对话框中点击「打开」。

3. 在「系统设置」→「隐私与安全性」中，如果提示「AiCash」已损坏，点击「仍要打开」。

## 常见问题

**Q: 提示应用已损坏？**
A: 执行上述命令或在系统设置中允许运行。

**Q: 无法打开应用？**
A: 确保已将应用拖到 Applications 文件夹，而不是直接在 DMG 中运行。

**Q: 如何卸载？**
A: 直接删除 Applications 文件夹中的 AiCash.app 即可。
EOF

# Create English installation guide
cat > "$TMP_DIR/INSTALL_GUIDE.md" << 'EOF'
# AiCash Installation Guide

## Installation Steps

1. Drag **AiCash.app** to the **Applications** folder

2. Since the app is unsigned, run the following command to remove the quarantine attribute:

```bash
sudo xattr -r -d com.apple.quarantine /Applications/AiCash.app
```

Alternatively, right-click on AiCash.app and select "Open", then click "Open" in the dialog.

3. In "System Settings" → "Privacy & Security", if prompted that "AiCash" is damaged, click "Open Anyway".

## FAQ

**Q: App is damaged?**
A: Run the command above or allow it in System Settings.

**Q: Can't open the app?**
A: Make sure you've copied it to Applications folder, not running from DMG.

**Q: How to uninstall?**
A: Simply delete AiCash.app from Applications folder.
EOF

# Check if create-dmg is installed
if command -v create-dmg &> /dev/null; then
  echo -e "${GREEN}Using create-dmg...${NC}"
  create-dmg \
    --volname "AiCash" \
    --window-pos 200 120 \
    --window-size 700 450 \
    --icon-size 80 \
    --icon "AiCash.app" 150 250 \
    --icon "安装指南.md" 350 250 \
    --icon "INSTALL_GUIDE.md" 350 350 \
    --hide-extension "AiCash.app" \
    --app-drop-link 550 250 \
    --no-internet-enable \
    "$DMG_NAME" \
    "$TMP_DIR/" 2>/dev/null || true
else
  echo -e "${YELLOW}create-dmg not found, using hdiutil...${NC}"
  echo -e "${YELLOW}Install create-dmg with: brew install create-dmg${NC}"
  hdiutil create -volname "AiCash" -srcfolder "$TMP_DIR" -ov -format UDZO "$DMG_NAME"
fi

# Clean up
rm -rf "$TMP_DIR"

# Calculate checksum
shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256"

echo -e "${GREEN}✓ DMG created: $DMG_NAME${NC}"
echo -e "${GREEN}✓ Checksum: ${NC}"
cat "${DMG_NAME}.sha256"

echo ""
echo -e "${GREEN}To test the DMG:${NC}"
echo -e "  1. Open $DMG_NAME"
echo -e "  2. Drag AiCash to Applications"
echo -e "  3. Launch from Applications folder"
