#!/usr/bin/env bash
# Set up and build this fork (paulsavare) as a Linux desktop app on Ubuntu.
#
#   git clone -b paulsavare https://github.com/pbreed/avarex.git
#   cd avarex && bash setup-avarex-linux.sh
#
# Run from inside the clone. Run it from anywhere else and it clones the fork
# into ./avarex first.
#
# Linux is the easy desktop target for this project: its plugin list contains
# ZERO Firebase plugins (Windows has 4), and Firebase's prebuilt C++ libs are
# exactly what fails to link on Windows. desktop_webview_auth builds against
# webkit2gtk here instead of needing Windows ATL. Upstream maintains Linux --
# there is a snap.yaml workflow in CI.
set -euo pipefail

FORK_URL="https://github.com/pbreed/avarex.git"
BRANCH="paulsavare"
FLUTTER_VER="3.47.2"          # pinned to match upstream CI
FLUTTER_DIR="$HOME/flutter"

echo "==> Build dependencies"
sudo apt-get update
sudo apt-get install -y \
    curl git unzip xz-utils zip \
    clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-12-dev \
    libsecret-1-dev libsqlite3-dev \
    libwebkit2gtk-4.1-dev

echo "==> Flutter $FLUTTER_VER"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    curl -L -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VER}-stable.tar.xz"
    tar -xf /tmp/flutter.tar.xz -C "$HOME"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
grep -q 'flutter/bin' "$HOME/.bashrc" || echo 'export PATH="$HOME/flutter/bin:$PATH"' >> "$HOME/.bashrc"
flutter --version

echo "==> Source"
if [ ! -f pubspec.yaml ]; then
    [ -d avarex/.git ] || git clone -b "$BRANCH" "$FORK_URL" avarex
    cd avarex
fi
echo "    building $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"

# lib/firebase_options.dart is gitignored but IMPORTED by main.dart, so a fresh
# clone cannot compile without it. CI generates the real one via flutterfire.
# Constants.firebaseAvailable excludes Linux, so here the stub only has to
# satisfy the compiler -- Firebase.initializeApp is never reached.
if [ ! -f lib/firebase_options.dart ]; then
    echo "==> Writing firebase_options.dart stub"
    cat > lib/firebase_options.dart <<'DART'
// LOCAL DEVELOPMENT STUB -- not from flutterfire configure.
// Required only because main.dart imports it. Constants.firebaseAvailable
// excludes Linux, so Firebase.initializeApp is never reached here.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions
{
    static const FirebaseOptions _stub = FirebaseOptions(
        apiKey: 'AIzaSyDUMMYLOCALSTUBKEY00000000000000000',
        appId: '1:000000000000:android:0000000000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'avarex-local-stub',
        storageBucket: 'avarex-local-stub.appspot.com',
    );

    static FirebaseOptions get currentPlatform => _stub;
}
DART
fi

echo "==> Building"
flutter config --enable-linux-desktop
flutter pub get
flutter build linux --debug

echo
echo "Done.  Run with:   flutter run -d linux"
echo "Charts, plates and databases must be downloaded again on this machine."
echo "Android APK builds also need android/key.properties + the .jks keystore,"
echo "copied over by hand -- they are deliberately not in git."
