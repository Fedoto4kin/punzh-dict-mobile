import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// Known app-store installers. Sideload / site APK usually has null or a
/// browser / packageinstaller package — those are treated as non-store.
const Set<String> storeInstallerPackages = {
  "ru.vk.store", // RuStore
  "com.android.vending", // Google Play
};

const MethodChannel _installSourceChannel = MethodChannel(
  "host.punzh.punzh_dict/install_source",
);

/// Pure check: [installer] package name belongs to a known store.
bool installerIsStore(
  String? installer, {
  Set<String> stores = storeInstallerPackages,
}) {
  final value = installer?.trim();
  if (value == null || value.isEmpty) return false;
  return stores.contains(value);
}

/// Whether this install was delivered by a known store (F2: hide app-update UI).
///
/// Non-Android / channel failure → `false` (show check — safer for sideload).
Future<bool> isStoreInstall({
  Set<String> stores = storeInstallerPackages,
  MethodChannel? channel,
}) async {
  if (kIsWeb || !Platform.isAndroid) return false;
  final ch = channel ?? _installSourceChannel;
  try {
    final raw = await ch.invokeMethod<String?>("getInstallerPackageName");
    return installerIsStore(raw, stores: stores);
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
