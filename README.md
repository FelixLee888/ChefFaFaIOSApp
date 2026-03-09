# ChefFaFaIOSApp

iOS app for Chef Fafa, built with SwiftUI and visually aligned to the Chef Fafa recipe website.

## Prerequisites

- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Install XcodeGen (if needed):

```bash
brew install xcodegen
```

## Quick Start

```bash
xcodegen generate
open ChefFaFaIOSApp.xcodeproj
```

Then run the `ChefFaFaIOSApp` scheme in Xcode.

## Current Feature Set

- Uses the same recipe source dataset as the website (`recipes.json`).
- Uses the same hero/logo/recipe media assets from the website.
- English / Traditional Chinese / Japanese language switcher.
- Search by title, summary, tags, cuisine, type, and ingredients.
- Cuisine and type chip filters with live result counts.
- Website-style recipe cards and full recipe detail pages.
- Source URL and Google Doc links in recipe detail.

## Run Tests

```bash
xcodebuild test \
  -project ChefFaFaIOSApp.xcodeproj \
  -scheme ChefFaFaIOSApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Project Layout

- `project.yml`: Source-of-truth Xcode project spec.
- `ChefFaFaIOSApp/App`: App entry point.
- `ChefFaFaIOSApp/Features`: SwiftUI screens.
- `ChefFaFaIOSApp/Models`: App data models.
- `ChefFaFaIOSApp/Services`: Local data loading.
- `ChefFaFaIOSApp/Resources`: Bundled website assets/videos/images and recipe JSON.
- `ChefFaFaIOSAppTests`: Unit tests.
