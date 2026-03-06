# AiCash

A beautiful macOS menu bar app to track AI service costs and usage across multiple providers.
<img width="1392" height="1049" alt="image" src="https://github.com/user-attachments/assets/8d95140b-b559-4f08-aee0-6a8245cf52b5" />


## Features

- **Multi-Provider Support**: Track Cursor, BLT, and ZenMux AI services
- **Real-time Cost Tracking**: Monitor daily usage and spending
- **Status Bar Integration**: Quick cost overview directly in your menu bar
- **Configurable Settings**: Customize history range (7-90 days) and page limits (50-500 records)
- **Modern UI**: Blur transparent background with native macOS design
- **Auto-refresh**: Configurable refresh intervals (15-120 minutes)

## Screenshots

The app features a clean, modern interface with:
- Split-view layout showing provider list and detailed usage charts
- Translucent blur background for a native macOS feel
- Status bar cost display for quick reference
- Comprehensive usage history and event tracking

## Installation

### Quick Install (One Command)
Run this command in your terminal to download the latest version:

```bash
curl -sL https://github.com/SSBun/AiCash/raw/main/install_latest.sh | bash
```

The script will:
1. Download the latest AiCash DMG to your Downloads folder
2. Open the DMG file automatically

Then:
1. Drag AiCash.app to your Applications folder
2. If macOS shows "AiCash is damaged" error, run:
   ```bash
   xattr -rd com.apple.quarantine /Applications/AiCash.app
   ```

Or clone the repository and run the script locally:

```bash
git clone https://github.com/SSBun/AiCash.git
cd AiCash
./install_latest.sh
```

### Manual Install
1. Download the latest `AiCash-x.x.x.dmg` from the [Releases](https://github.com/SSBun/AiCash/releases) page
2. Open the DMG file
3. Drag AiCash to your Applications folder
4. If macOS shows "AiCash is damaged" error, run:
   ```bash
   xattr -rd com.apple.quarantine /Applications/AiCash.app
   ```

## Configuration

### Adding Providers

**Cursor AI:**
- Paste your browser cookies from cursor.com
- Access via Developer Tools → Application → Cookies

**BLT Provider:**
- Enter your User ID and API Token
- Available from your BLT dashboard

**ZenMux:**
- Paste the complete cURL command from browser network tab
- Captured from zenmux.ai API requests

### Settings

- **History Range**: Choose how many days of history to fetch (7-90 days)
- **Page Limit**: Set maximum records per API request (50-500)
- **Refresh Interval**: Auto-refresh frequency (15-120 minutes)
- **Launch at Login**: Start automatically when you log in

## Usage

- **Menu Bar**: Shows today's cost for quick reference
- **Left Click**: Open detailed usage view
- **Right Click**: Access app menu (Show Window, Quit)
- **Settings**: Configure providers and preferences

## Requirements

- macOS 15.0 or later
- Active accounts with supported AI providers

## Privacy

AiCash stores all data locally on your Mac. No usage data is transmitted to external servers except for fetching your own usage information from the configured AI providers.

## Development

Built with:
- SwiftUI for modern macOS UI
- Native macOS APIs for menu bar integration
- UserDefaults for settings persistence
- Async/await for network operations

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions welcome! Please feel free to submit issues and pull requests.
