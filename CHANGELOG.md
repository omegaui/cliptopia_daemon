
# 0.0.4
- forces xclip on wayland sessions by default

# 0.0.3
- Brings Daemon State Management
- Fixed Unresponsiveness of a long-running daemon
- Optimized Start up

# 0.0.2 - version bumped to 0.0.2
> ### Breaking Changes
> This update will clear the clipboard cache as the new model
precalculates the entity size for faster cache optimizations that were earlier calculated by the daemon.

- Huge performance Boost 
- NEW Clipboard Entity Model Supporting precalculated cache size.
- Fixes dependency on cliptopia's copy script.
- Smart Instance Management.
- No longer allows running more than one daemon at the same time.
