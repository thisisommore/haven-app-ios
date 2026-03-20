# XXDK

This folder includes all the bindings with helper functions \
For previews a mock is included in MockXXDK.swift \
Both mock and real uses XXDK Protocol so that everything is in sync.

XXDK is organised in 3 parts
Core, Foundation, Receivers.

## Init

For new user this functions are run in order

- downloadNdf
  downloads networt defination file
- newCmix
  creates new cmix using BindingsNewCmix
  then loads that cmix using BindingsLoadCmix
- startNetworkFollower
  starts network synchronization
- generateIdentities
  calls BindingsGenerateChannelIdentity to generate multiple identies which user can select from
- setupClients
  user selected identity is passed to this function
  here dm client and channels manager is inited

For existing user

- downloadNdf is skipped
- generateIdentities is skipped
- loadCmix
  loads existing cmix using BindingsLoadCmix
- loadClients
  loadClients is called and then it uses existing channels manager and dm client
  called before starting network follower to avoid missing any events
- startNetworkFollower
  starts network synchronization

# Callbacks

XXDK includes channel manager and dm manager. \
This manager also calls callback events for messages. \
For example receive message, receive reaction. \
This callbacks are placed in MessageCallbacks folder.
