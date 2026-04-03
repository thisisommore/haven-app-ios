# Haven App

This project is based on the iOS example in [xxdk-examples](https://git.xx.network/xx_network/xxdk-examples/-/tree/f64201e9c426a64b15e9d2608003939f3c9184e5/iOS).

*Note: It should take less than 1 minute for the app to set up for a new user (this also depends on network conditions).*

# Setup

Follow these steps to get the app running locally with the iOS Simulator.

### Prerequisites
* **Xcode:** Developed with Xcode 26 (the current latest version should work).
* **CocoaPods:** Version 1.16.2 was used at the time of writing (the current latest version should work).

```bash
brew install cocoapods
```

### Installation

1. Install project dependencies:
```bash
pod install
```

2. Open the project in Xcode:
```bash
open iOSExample.xcworkspace
```

You should see the following in the file browser:

![Opening the iOS Project](README-images/xcode-open.png)


# Contributing

### Formatting
We use [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) to format our Swift files.

```bash
# Install
brew install swiftformat

# Run
swiftformat .
```

### Linting
We use [SwiftLint](https://github.com/realm/SwiftLint) to lint our Swift files.

```bash
# Install
brew install swiftlint

# Run
swiftlint .
```

# Architecture

## View Controller Pattern
Most of the app relies on a View Controller pattern. Logic and state management are placed in a controller (`+Controller.swift`). SwiftUI initializes that controller and calls the required functions and events.


## File Structure

### Main.swift & Entrypoint
Everything starts with `Main.swift`. It acts as a container for `Provider`and `Root`and should be kept as clean as possible (< 30 lines).
* **Provider:** Initializes all dependencies using Swift dependency and environment, providing all required global dependencies.
* **Root:** Handles all initial logic, including the navigation stack, deep links, and initial routing (e.g., separating new vs. returning users).

### Data
All persistent data-related code is stored in the `Data`folder. This includes:
* Database logic powered by `SQLiteData`.
* Secrets management using Apple Keychain.
* Key-value storage using `UserDefaults`.

#### Migrations
Write new database changes in `Data/Migration`. Raw SQL is preferred because it is easy to read and avoids the assumptions an ORM might make. Migrations should extend from `DatabaseMigrator`.

```swift
extension DatabaseMigrator {
  mutating func v2() {
    self.registerMigration("v1:init") { db in
      try #sql(
        """
        CREATE TABLE "hello"(
          "id" TEXT NOT NULL PRIMARY KEY
        ) STRICT
        """
      )
      .execute(db)
    }
  }
}
```
Migrations should then be called sequentially in `Database.swift`:
```swift
  migrator.v1()
  migrator.v2()
  migrator.v3()
  // ...
  try migrator.migrate(database)
```

### UI & Navigation
* **Navigation:** We use a `Destination`enum to define navigation destinations. (See `Navigation.swift`for more info).
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
            }
        }
    }
    ```
* **Pages:** All screens and pages are stored in the `Pages`folder. The entry point for a page is defined by `*.page.swift`.
    * *Previews* are heavily utilized to build UI quickly without waiting for heavy builds to complete.
    * `PreviewUtils`contains mock functions that can be attached to any preview to quickly set up the necessary data and environment.

### XXDK
All XXDK-related code (bindings, callbacks, documentation) is stored in the `XXDK`folder.
* **Best Practice:** When using XXDK, always use the `XXDKP`protocol. This ensures that mocks can be provided in-place without requiring major code changes (which is especially useful in SwiftUI Previews).


# Code Style
## Naming Conventions

### Controllers
Controllers follow the `+Controller` suffix pattern. They manage state and logic for swift views.
```swift
@Observable
class ChatController {
  var messages: [Message] = []
}
```

### Extensions
Use extension to separate group of code, for example 
```swift
Class A {props, init} 
extension A {methodA, methodB}
```

### +ABC.swift
In swift scope is shared so same file names in difference folders collide, therefore use patterns like +XYZ
to support its usage

### Protocols
Use protocols to support mock and previews, protocols allow to replace real implementation with mock \
Use protocols to define common type/methods.  \
For example we use CellWithContextMenu protocol to determine if the cell support context or not.

## Formatting

### Line Length
Try to keep everything under 500 lines

### Linting & Formatting
Lint and formatting configs are provided, use them to maintain codebase and catch bugs/errors early.

### SwiftUI View
For SwiftUI views, follow this strict property ordering:
1. Controller state
2. Normal vars (non-state, props, `@Binding`included)
3. Environment variables
4. `@Dependency`
5. Fetch hooks
6. `@State`/ `@FocusState`
7. Anything else (helper methods, constants)
8. `body`view goes last

**Example:**
```swift
struct ExampleView: View {
  // 1. Controller state
  @State private var controller = ExampleController()

  // 2. Normal vars / props / @Binding
  let title: String
  @Binding var isPresented: Bool

  // 3. Environment variables
  @EnvironmentObject private var appState: AppState
  @Environment(\.dismiss) private var dismiss

  // 4. Dependencies
  @Dependency(\.defaultDatabase) private var database

  // 5. Fetch hooks
  @FetchAll(Item.order { $0.name }) private var items: [Item]
  @FetchOne private var selectedItem: Item?

  // 6. States
  @State private var searchText = ""
  @FocusState private var isSearchFocused: Bool

  // 7. Anything else
  private func hello() {
    AppLogger.app.info("hello")
  }

  private var pageSize = 20

  // 8. Body
  var body: some View {
    Text(title)
  }
}
```