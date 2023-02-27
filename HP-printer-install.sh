#!/bin/bash

# Delete current printers
lpstat -p | awk '{print $2}' | while read printer
do
echo "Deleting Printer:" $printer
lpadmin -x $printer
done

# give rights to add printers
/usr/bin/security authorizationdb write system.preferences.printing allow
/usr/bin/security authorizationdb write system.print.operator allow
/usr/sbin/dseditgroup -o edit -n /Local/Default -a everyone -t group lpadmin
/usr/sbin/dseditgroup -o edit -n /Local/Default -a everyone -t group _lpadmin


# Install PKG - HP printer drivers

# Set constants
LOG_DIR="/Users/Shared/Logging"
PROCESSOR=$(uname -m)
LOG_FILE="${PROCESSOR}-Support-Installer-Logs-$(date +%Y%m%d-%H%M%S).log"

# Set URLs based on processor type
if [[ "$PROCESSOR" == "arm64" ]]; then
  APP_URLS=(
    "HTTPS://ftp.hp.com/pub/softlib/software12/HP_Quick_Start/osx/Installations/Essentials/macOS13/hp-printer-essentials-UniPS-6_1_0_1.pkg"
  )
else
  APP_URLS=(
    "HTTPS://ftp.hp.com/pub/softlib/software12/HP_Quick_Start/osx/Installations/Essentials/macOS13/hp-printer-essentials-UniPS-6_1_0_1.pkg"
  )
fi

# Define functions
install_dmg_app() {
  url="$1"
  dmg_name="$(basename "$url")"
  pkg_name="$(echo "$dmg_name" | sed -E 's/(.*)\..*/\1/').pkg"

  echo "Installing $dmg_name..."
  curl --silent --location --remote-name "$url"
  volume="$(hdiutil attach -nobrowse "$dmg_name" | grep Volumes | sed 's/.*\/Volumes\//\/Volumes\//')"
  cp -R "$volume"/*.app /Applications/
  hdiutil detach "$volume"
  pkgbuild --root "$volume" --identifier com.example.app "$pkg_name"
  installer -pkg "$pkg_name" -target /
  rm "$dmg_name" "$pkg_name"
}

install_pkg_app() {
  url="$1"
  pkg_name="$(basename "$url")"

  echo "Installing $pkg_name..."
  curl --silent --location --remote-name "$url"
  installer -pkg "$pkg_name" -target /
  rm "$pkg_name"
}

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Redirect output to log file
LOG_PIPE=$(mktemp -u)
mkfifo "$LOG_PIPE"
tee -a "$LOG_DIR/$LOG_FILE" < "$LOG_PIPE" &
exec 1> "$LOG_PIPE" 2>&1
rm "$LOG_PIPE"

# Log variable values
echo "PROCESSOR=$PROCESSOR"
for app_url in "${APP_URLS[@]}"; do
  echo "APP_URL=$app_url"
done

# Install applications
for app_url in "${APP_URLS[@]}"; do
  if [[ "$app_url" == *".dmg" ]]; then
    install_dmg_app "$app_url"
  elif [[ "$app_url" == *".zip" ]]; then
    echo "Downloading and installing $(basename "$app_url")..."
    curl --silent --location "$app_url" -o /tmp/app.zip
    unzip -q /tmp/app.zip -d /Applications/
    rm /tmp/app.zip
  elif [[ "$app_url" == *".pkg" ]]; then
    install_pkg_app "$app_url"
  else
    echo "Unsupported application format for $app_url"
  fi
done

# add printers
lpadmin -p Office-1-Printer -E -v ipp://10.5.5.241 -L "Office 1" -P "/Library/Printers/PPDs/Contents/Resources/HP Color LaserJet Pro MFP M477.gz"
lpadmin -p Office-2-Printer-Upstairs -E -v ipp://10.5.5.238 -L "Office 2 - Upstairs" -P "/Library/Printers/PPDs/Contents/Resources/HP Color LaserJet M553.gz"
