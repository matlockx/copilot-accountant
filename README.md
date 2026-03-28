# Copilot Accountant

A native macOS menu bar app that tracks your GitHub Copilot premium request usage in real-time.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-6.0+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Real-time Usage Tracking**: Monitor your premium request consumption as a percentage in the menu bar
- **Color-coded Status**: Visual indicators (🟢🟡🟠🔴) based on your usage level
- **Detailed Statistics**: 
  - Daily usage charts for the current month
  - Breakdown by AI model (Claude Opus, GPT-4, etc.)
  - Breakdown by product (Chat, CLI, etc.)
- **Budget Alerts**: Notifications at 80% and 90% usage thresholds
- **Automatic Polling**: Checks GitHub API every 5 minutes (configurable)
- **Secure Token Storage**: GitHub token safely stored in macOS Keychain
- **Persistent Cache**: Usage data cached locally for offline viewing

## Screenshots

### Menu Bar Display
Shows usage percentage with color-coded status indicator.

### Dropdown Menu
Quick stats with:
- Current usage / budget
- Days until monthly reset
- Top model used
- Quick actions

### Detailed Statistics Window
- Daily usage chart
- Model usage breakdown (pie chart)
- Product usage breakdown

### Settings
- GitHub username and token configuration
- Monthly budget customization
- Polling interval adjustment
- Notification preferences

## Requirements

- macOS 14.0 (Sonoma) or later
- GitHub account with Copilot subscription
- GitHub Personal Access Token
- Swift 6.0+ (included with Command Line Tools)

## Installation

### Quick Build (No Xcode Required!)

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/copilot-accountant.git
   cd copilot-accountant
   ```

2. Build using the direct compiler:
   ```bash
   ./build-direct.sh release
   ```

3. Run the app:
   ```bash
   .build/release/CopilotAccountant
   ```

### Alternative: Build with Xcode

1. Open in Xcode:
   ```bash
   open Package.swift
   ```

2. Build and run (Cmd+R)

### Creating a Standalone App

1. Build for release:
   ```bash
   ./build-direct.sh release
   ```

2. Create app bundle:
   ```bash
   mkdir -p CopilotAccountant.app/Contents/{MacOS,Resources}
   cp .build/release/CopilotAccountant CopilotAccountant.app/Contents/MacOS/
   cp Resources/Info.plist CopilotAccountant.app/Contents/
   chmod +x CopilotAccountant.app/Contents/MacOS/CopilotAccountant
   mv CopilotAccountant.app /Applications/
   ```
   
2. Move the app to your Applications folder

3. (Optional) Add to Login Items:
   - System Settings → General → Login Items
   - Or enable "Launch at Login" in app settings

## Setup

### 1. Create a GitHub Personal Access Token

1. Go to [GitHub Settings → Tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Give it a descriptive name (e.g., "Copilot Accountant")
4. Select the following scopes:
   - `read:user` - Read your user profile
   - `read:org` - Read organization data (if applicable)
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again!)

### 2. Configure the App

1. Launch Copilot Accountant
2. Click the menu bar icon
3. Click "Settings"
4. Enter your:
   - **GitHub Username**: Your GitHub username
   - **Personal Access Token**: Paste the token you just created
5. Click "Save Token"
6. Click "Validate" to test the connection
7. Adjust your settings:
   - **Monthly Budget**: Default is 300 requests (adjust if you have a different plan)
   - **Polling Interval**: How often to check for updates (default 5 minutes)
   - **Notifications**: Toggle alerts at 80% and 90%
8. Click "Save"

### 3. Understanding Your Plan

Different Copilot plans have different premium request budgets:

- **Copilot Free**: Limited requests per month
- **Copilot Pro**: 300 premium requests/month (default)
- **Copilot Pro+**: Higher limit
- **Copilot Business/Enterprise**: Varies by organization

Check your plan at [github.com/settings/billing](https://github.com/settings/billing)

## Usage

### Menu Bar Icon

The menu bar shows your current usage as a percentage with a color indicator:
- 🟢 Green: 0-59% used (safe)
- 🟡 Yellow: 60-79% used (moderate)
- 🟠 Orange: 80-89% used (high)
- 🔴 Red: 90-100% used (critical)

### Dropdown Menu

Click the menu bar icon to see:
- Current usage details
- Days until monthly reset (1st of each month)
- Last update time
- Quick access to:
  - Detailed Statistics
  - Refresh Now
  - Settings
  - Quit

### Detailed Statistics

Click "Detailed Statistics" to open a window with:
- **Daily Usage Chart**: Bar chart showing requests per day
- **Model Breakdown**: Pie chart of which AI models you've used
- **Product Breakdown**: List of Copilot features you've used

### Notifications

The app sends macOS notifications when:
- You reach 80% of your budget
- You reach 90% of your budget
- Your budget will reset tomorrow

## Troubleshooting

### "No data available"

- Check that your username and token are correct in Settings
- Click "Validate" to test your connection
- Ensure your GitHub account has an active Copilot subscription
- Check your internet connection

### "Token validation failed"

- Verify your token has the correct scopes (`read:user`)
- Try regenerating your token on GitHub
- Make sure you copied the entire token without extra spaces

### "Failed to fetch usage data"

- GitHub API may be temporarily unavailable
- You might have hit the API rate limit (unlikely with default 5-minute polling)
- Check [GitHub Status](https://www.githubstatus.com/)

### High CPU usage

- Increase the polling interval in Settings (e.g., 10 or 15 minutes)
- The app only fetches data periodically, so CPU usage should be minimal

## API Information

This app uses the GitHub REST API endpoint:
```
GET /users/{username}/settings/billing/premium_request/usage
```

API documentation: [GitHub Billing Usage API](https://docs.github.com/en/rest/billing/usage)

## Privacy & Security

- Your GitHub token is stored securely in the macOS Keychain
- All API requests are made directly from your computer to GitHub (no third-party servers)
- Usage data is cached locally on your machine
- No telemetry or analytics are collected by this app

## Technical Details

- **Language**: Swift 6.0+
- **Framework**: SwiftUI
- **Platform**: macOS 14.0+ (Sonoma)
- **Architecture**: Native macOS menu bar application
- **Storage**: UserDefaults (config/cache) + Keychain (token)
- **Charts**: Swift Charts framework (SectorMark requires macOS 14.0)

## Project Structure

```
CopilotAccountant/
├── Sources/
│   ├── App/
│   │   ├── CopilotAccountantApp.swift    # Main app entry point
│   │   └── AppDelegate.swift             # Menu bar management
│   ├── Models/
│   │   ├── UsageData.swift               # Usage response models
│   │   └── BudgetConfig.swift            # Configuration model
│   ├── Services/
│   │   ├── GitHubAPIService.swift        # API client
│   │   ├── KeychainService.swift         # Secure token storage
│   │   ├── NotificationService.swift     # System notifications
│   │   └── UsageTracker.swift            # Main tracking logic
│   └── Views/
│       ├── MenuBarView.swift             # Dropdown menu UI
│       ├── DetailedStatsView.swift       # Statistics window
│       └── SettingsView.swift            # Settings window
└── Package.swift                          # Swift Package Manager manifest
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Future Enhancements

- [ ] Export usage data to CSV
- [ ] Weekly/monthly usage reports
- [ ] Multiple account support
- [ ] Custom alert thresholds
- [ ] Menubar text customization
- [ ] Dark mode icon variants
- [ ] Historical usage trends (multiple months)
- [ ] Sparkle auto-update integration

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built with SwiftUI and Swift Charts
- Uses GitHub REST API
- Inspired by the need to track Copilot premium request usage

## Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/yourusername/copilot-accountant/issues) page.

## Disclaimer

This is an unofficial third-party application and is not affiliated with, endorsed by, or connected to GitHub or Microsoft. GitHub and Copilot are trademarks of their respective owners.
