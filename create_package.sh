#!/bin/bash

set -euo pipefail

### === CONFIGURAZIONE === ###
ORIGINAL_PKG_PATH="./MyOriginal.pkg"         # <-- Cambia con il path al tuo pkg
WRAPPER_ID="com.example.wrapper"             # <-- Cambia con il tuo bundle ID
WRAPPER_NAME="WrappedInstaller.pkg"
CERT_NAME="Developer ID Installer: Mario Rossi (TEAMID1234)"  # <-- Cambia col tuo certificato
NOTARIZE_APPLE_ID="mario@example.com"        # <-- Il tuo Apple ID
NOTARIZE_PASSWORD="@keychain:AC_PASSWORD"    # <-- App specific password salvata nel portachiavi
TEAM_ID="TEAMID1234"                         # <-- Il tuo Team ID
### ======================= ###

WORKDIR=$(mktemp -d)
SCRIPTS_DIR="$WORKDIR/scripts"
PAYLOAD_DIR="$WORKDIR/payload"
UNSIGNED_PKG="$WORKDIR/unsigned.pkg"
SIGNED_PKG="$WORKDIR/signed.pkg"
WRAPPER_ZIP="$WORKDIR/wrapped_pkg.zip"

mkdir -p "$SCRIPTS_DIR" "$PAYLOAD_DIR"

echo "[1] Copio il pkg originale nel payload"
cp "$ORIGINAL_PKG_PATH" "$PAYLOAD_DIR/InnerInstaller.pkg"

echo "[2] Creo lo script postinstall"
cat > "$SCRIPTS_DIR/postinstall" <<EOF
#!/bin/bash
echo "[Wrapper] Eseguo comandi personalizzati..."
echo "Installazione avviata" >> /tmp/wrapper.log

PKG="/Library/Application Support/InnerInstaller.pkg"
if [ -f "\$PKG" ]; then
    echo "[Wrapper] Lancio InnerInstaller.pkg" >> /tmp/wrapper.log
    installer -pkg "\$PKG" -target / >> /tmp/wrapper.log 2>&1
    rm -f "\$PKG"
else
    echo "[Wrapper] ERRORE: InnerInstaller.pkg non trovato" >> /tmp/wrapper.log
    exit 1
fi

exit 0
EOF

chmod +x "$SCRIPTS_DIR/postinstall"

echo "[3] Creo pkg non firmato"
pkgbuild \
  --identifier "$WRAPPER_ID" \
  --version "1.0" \
  --scripts "$SCRIPTS_DIR" \
  --root "$PAYLOAD_DIR" \
  --install-location "/Library/Application Support" \
  "$UNSIGNED_PKG"

echo "[4] Firmo il pkg"
productsign --sign "$CERT_NAME" "$UNSIGNED_PKG" "$SIGNED_PKG"

echo "[5] Zippatura per notarizzazione"
cd "$WORKDIR"
zip -r "$WRAPPER_ZIP" "$(basename "$SIGNED_PKG")"

echo "[6] Invio a notarizzazione"
xcrun notarytool submit "$WRAPPER_ZIP" \
  --apple-id "$NOTARIZE_APPLE_ID" \
  --password "$NOTARIZE_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait

echo "[7] Applico la stapling"
xcrun stapler staple "$SIGNED_PKG"

echo "[✅] Pacchetto firmato e notarizzato: $SIGNED_PKG"
cp "$SIGNED_PKG" "./$WRAPPER_NAME"

# Cleanup automatico
rm -rf "$WORKDIR"
