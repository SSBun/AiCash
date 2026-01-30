# AiCash

A beautiful macOS menu bar app to track AI service costs and usage across multiple providers.

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

1. Download the latest release from [Releases](https://github.com/SSBun/AiCash/releases)
2. Drag AiCash.app to your Applications folder
3. Launch the app and configure your AI providers

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
