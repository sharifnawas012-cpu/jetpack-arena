# Building the APK on your PC (free)
1. Install Godot 4.3 (godotengine.org) and Export Templates (Editor -> Manage Export Templates).
2. Install JDK 17 and Android command-line tools; with `sdkmanager` install `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`.
3. Create a debug keystore: `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12`
4. Godot: Editor -> Editor Settings -> Export -> Android: set Android SDK path, Java SDK path, debug keystore (user `androiddebugkey`, password `android`).
5. Open the project, Project -> Export -> Android -> *Export Project* (debug) -> `JetpackArena.apk`.
6. For a shareable release APK create your own release keystore and fill it in the preset; sign it yourself (keep the keystore private).
Permissions already set: INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE (needed for LAN play).
