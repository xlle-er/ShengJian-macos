# Replace completed build artifacts by rename; never truncate a running Mach-O.
publish_bundle() {
  local staged_bundle="$1" destination_bundle="$2"
  local previous_bundle="${destination_bundle}.previous.$$"
  if [ -e "$destination_bundle" ]; then mv "$destination_bundle" "$previous_bundle"; fi
  if ! mv "$staged_bundle" "$destination_bundle"; then
    if [ -e "$previous_bundle" ]; then mv "$previous_bundle" "$destination_bundle"; fi
    return 1
  fi
  if [ -e "$previous_bundle" ]; then rm -rf "$previous_bundle"; fi
}
