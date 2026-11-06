# Use a stable local development identity so TCC can recognize successive builds.
resolve_signing_identity() {
  if [ -n "${SHENG_CODESIGN_IDENTITY:-}" ]; then
    printf '%s\n' "$SHENG_CODESIGN_IDENTITY"
    return
  fi
  local selected_identity
  selected_identity="$(/usr/bin/security find-identity -v -p codesigning | /usr/bin/awk '/Apple Development:/ {print $2; exit}')"
  if [ -n "$selected_identity" ]; then
    printf '%s\n' "$selected_identity"
  elif [ "${SHENG_ALLOW_ADHOC:-0}" = 1 ]; then
    printf '%s\n' '-'
  else
    echo 'No Apple Development signing identity. Set SHENG_CODESIGN_IDENTITY, or explicitly use SHENG_ALLOW_ADHOC=1 for build-only previews (capture authorization may reset after rebuilding).' >&2
    return 1
  fi
}
