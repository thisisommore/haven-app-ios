# XXDK

`XXDK` is the concrete implementation used by the app to work with the xx network bindings.
It owns the cmix lifecycle, identity state, network follower, DM client, channels manager, and setup progress exposed to the UI through `status`.

# XXDKP for mocks

`XXDKP` is the shared protocol that the app uses instead of depending directly on `XXDK`.
Views are written against `T: XXDKP`, so the real implementation (`XXDK`) and the mock implementation (`XXDKMock` in `MockXXDK.swift`) stay aligned.
This makes previews and test-style flows work without changing app code or touching the real network.

# Setup

### Register

For a new user, the setup flow is:

- `downloadNdf`
- `newCmix`
- `startNetworkFollower`
- `generateIdentities`
- `setupClients`

What each step does:

- `downloadNdf` downloads and verifies the network definition file required for cmix setup.
- `newCmix` creates a new cmix instance, then immediately loads it.
- `startNetworkFollower` starts network synchronization.
- `generateIdentities` creates candidate identities and codenames for the user to pick from.
- `setupClients` uses the selected private identity to initialize notifications, the DM client, remote KV, and the channels manager.

### Login

For an existing user, the setup flow is:

- `loadCmix`
- `loadSavedPrivateIdentity`
- `loadClients`
- `startNetworkFollower`

What each step does:

- `loadCmix` loads the existing cmix instance.
- `loadSavedPrivateIdentity` restores the previously saved private identity.
- `loadClients` restores the public identity, notifications, DM client, remote KV, and the existing channels manager.
- `startNetworkFollower` starts network synchronization after the existing clients are loaded.

### Logout

`logout()` performs a full XXDK state reset:

- stops the network follower
- waits briefly for running processes to finish
- removes the cmix instance from the bindings-side tracker
- clears XXDK in-memory references such as channels, DM, cmix, remote KV, and listeners
- clears local callback caches
- deletes and recreates the app state directory
- resets published identity and progress state

It does not clear the app database. If a full local reset is needed, DB cleanup must be done separately.

# Callbacks

`XXDK` includes both a channels manager and a DM manager.
These managers emit callback events for message-related activity such as receiving messages, reactions, deletes, and channel UI updates.
The callback bridge code lives in the `MessageCallbacks` folder.

# Dependencies

Main dependencies used in this folder:

- `Bindings` for the generated xx network / cmix bridge
- `Foundation` for data, files, JSON, and base types
- `SwiftUI` because `XXDK` conforms to `ObservableObject`
- `Dependencies` for app dependency injection
- `SQLiteData` for setup-time and bootstrap persistence work
- `Kronos` for the time source passed into the bindings layer

# Bindings

`Bindings.swift` provides Swift-style wrappers around the generated C/ObjC bindings.
It exists so higher-level code can use normal Swift APIs instead of dealing with raw `NSError` pointers and manual JSON decoding at every call site.

What it does:

- converts `NSError` out-parameter patterns into `throws`
- keeps raw bindings calls centralized in `BindingsStatic`, `BindingsChannelsManagerWrapper`, and `BindingsDMClientWrapper`
- parses structured binding responses before returning them
- uses the shared `Parser` helper so callers receive typed models instead of raw JSON `Data`

Examples of parsed return types include `ChannelJSON`, `IdentityJSON`, `ShareURLJSON`, and `ChannelSendReportJSON`.
This means the caller gets a modern Swift error plus a parsed object when the binding returns structured data.