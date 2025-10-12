# Agent Instructions for Rucord

## Build & Test Commands
- Build: `xcodebuild -scheme Rucord -project Rucord.xcodeproj -destination 'generic/platform=iOS' build`
- Requires: Xcode 18+, Swift 6, SwiftUI, iOS deployment target
- Open in Xcode: `Rucord.xcodeproj`
- If you need to run the app in a simulator, use an iPhone 16 with iOS 18.6

## Architecture
- SwiftUI iOS app for NZ Road User Charges (RUC) tracking
- Core files: `RucordApp.swift` (entry), `Models.swift` (data), `CarStore.swift` (persistence), `Views.swift` (UI)
- Data: JSON persistence in Documents directory, ObservableObject pattern
- Models: `Car` (plate, expiryOdometer, entries), `OdometerEntry` (date, value, id)

## Code Style
- **Naming**: PascalCase for types, camelCase for properties/functions
- **SwiftUI**: Use `@EnvironmentObject` for shared data, `@State` for local state
- **Navigation**: Modern `NavigationStack` with `navigationDestination(for:)`
- **Protocols**: Conform to `Identifiable`, `Codable`, `Equatable` for models
- **Error Handling**: Use optionals with `guard let`/`if let`, `print()` for debugging
- **Organization**: Separate Models, Store (data), Views (UI) - use extensions for computed properties. Break views out into seperate files (per view) where appriate
- **State**: Boolean states use `showing` prefix (e.g., `showingAdd`)
- **Accessibility**: Include `.accessibilityLabel()` for UI elements
- **Lint** you have `swiftlint` available, and should always use it to check and fix linting errors
