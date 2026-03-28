# Changelog

All notable changes to Copilot Accountant will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-28

### Added
- 🎉 Initial release of Copilot Accountant
- Real-time GitHub Copilot premium request usage tracking
- Menu bar status indicator with color-coded alerts
- Detailed statistics window with charts:
  - Daily usage bar chart
  - Model usage pie chart
  - Product usage breakdown
- Settings view for configuration:
  - GitHub username and token management
  - Monthly budget customization
  - Polling interval adjustment
  - Notification preferences
- Secure token storage using macOS Keychain
- System notifications at 80% and 90% usage thresholds
- Automatic polling every 5 minutes (configurable)
- Local data caching for offline viewing
- Days until monthly reset counter
- Budget validation
- Manual refresh option
- Error handling and user-friendly error messages

### Technical Details
- Built with Swift 5.9 and SwiftUI
- Minimum macOS version: 13.0 (Ventura)
- Uses Swift Charts for data visualization
- GitHub REST API integration
- UserDefaults for configuration persistence
- Keychain Services for secure token storage

### Documentation
- Comprehensive README with setup instructions
- Quick setup guide (SETUP.md)
- Build script for easy compilation
- MIT License

## [Unreleased]

### Planned Features
- Export usage data to CSV
- Weekly/monthly usage reports
- Multiple account support
- Custom alert thresholds
- Menubar text customization
- Dark mode icon variants
- Historical usage trends (multiple months)
- Sparkle auto-update integration
- GitHub Actions workflow for automated builds

---

[1.0.0]: https://github.com/yourusername/copilot-accountant/releases/tag/v1.0.0
