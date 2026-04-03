# Intro

Haven App for iOS and iPadOS \
This is based on the iOS example in xxdk-examples \
https://git.xx.network/xx_network/xxdk-examples/-/tree/f64201e9c426a64b15e9d2608003939f3c9184e5/iOS

# Getting started

#### Steps to getting this run locally with simulator.
### Get XCode 
This was developed with Xcode 26 \
Current latest version should work

### Get CocoaPod
CocoaPod 1.16.2 was used at time of writing this \
Current latest version should work
```bash
brew install cocoapods
```
### Install dependencies
```bash
pod install
```

### Open project
```bash
open iOSExample.xcworkspace
```
And you should see the following in the file browser:

![Opening the iOS Project](README-images/xcode-open.png)

# File Structure

### Entrypoint

Everything starts with Main.swift \
It initiates Provider and Root component \
Root handles all the initial logic,
like

- navigation stack
- deep link
- initial routing according to new or old user

### Navigation

For navigation, we use a Destination enum with navigation destination

```swift
enum Destination: Hashable {
    case home
    case landing
    // ...
}

extension Destination {
    @MainActor @ViewBuilder
    func _destinationView() -> some View {
        switch self {
        case .landing:
            LandingPage<XXDK>()

        case .home:
            HomeView<XXDK>()
        // ...
```

See Navigation.swift for more info

### Pages

All pages/screens are stored in the Pages folder, the entry point is defined by \*.page.swift \
Previews are used to quickly build UI without waiting for heavy builds to complete. \
PreviewUtils contains mock function which can be attached to any preview to quickly setup all necessary data and environment for preview.

### Data

All persistant data related code is stored in Data folder,
it includes database powered by SQLiteData
secrets using apple keychain
key value like storage using user defaults

### XXDK

All XXDK related code is in the XXDK folder, including documentation
This includes bindings, callbacks, etc.

# Contributing

## Formatting

SwiftFormat is used to format Swift files
https://github.com/nicklockwood/SwiftFormat

Installing

```bash
brew install swiftformat
```

Running

```
swiftformat .
```

## Linting

SwiftLint is used to format Swift files
https://github.com/realm/SwiftLint

Installing

```bash
brew install swiftlint
```

Running

```
swiftlint .
```

# Code patterns
For swiftui view follow this order
- Controller state
- normal vars, non state, can be props, @Binding included
- environment variables
- @Dependency
- fetch hooks
- @States
- anything else here
- then body views go last

```swift
struct ExampleView: View {
  // Controller state
  @State private var controller = ExampleController()

  // Normal vars / props / @Binding
  let title: String
  @Binding var isPresented: Bool

  // Environment variables
  @EnvironmentObject private var appState: AppState
  @Environment(\.dismiss) private var dismiss

  // Dependencies
  @Dependency(\.defaultDatabase) private var database

  // Fetch hooks
  @FetchAll(Item.order { $0.name }) private var items: [Item]
  @FetchOne private var selectedItem: Item?

  // States
  @State private var searchText = ""
  @FocusState private var isSearchFocused: Bool

  // Anything else
  private func hello() {
    AppLogger.app.info("hello")
  }

  private var pageSize = 20

  var body: some View {
    Text(title)
  }
}
```