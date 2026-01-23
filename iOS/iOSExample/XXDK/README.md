# XXDK

This folder includes all the bindings with helper functions \
For previews a mock is included in MockXXDK.swift \
Both mock and real uses XXDK Protocol so that everything is in sync.

XXDK is organised in 3 parts
Core, Foundation, Receivers.

# Core

Core includes all the files required for initiating xxdk, cmix, and exposes some functions to post messages on network.

## Init

For new user this functions are run in order

- downloadNdf
  downloads networt defination file
- setUpCmix
  creates new cmix using BindingsNewCmix
  then loads that cmix using BindingsLoadCmix
- startNetworkFollower
  starts network synchronization
- generateIdentities
  calls BindingsGenerateChannelIdentity to generate multiple identies which user can select from
- load
  user selected identity is passed to this function
  here dm client and channels manager is inited

For existing user

- downloadNdf is skipped
- generateIdentities is skipped
- setUpCmix
  loads existing cmix using BindingsLoadCmix
- load
  load is called without any identity(nil) and then it uses existing channels manager and dm client
  called before starting network follower to avoid missing any events
- startNetworkFollower
  starts network synchronization

# Receivers

XXDK includes channel manager and dm manager. \
This manager also emits events for messages. \
For example receive message, receive reaction. \
This receivers are placed in Recivers folder.
