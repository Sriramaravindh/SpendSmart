import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric / device-credential app lock. Static methods, defensively coded so
/// an unsupported platform or an auth plugin error never crashes the app.
///
/// NOTE: targets local_auth ^2.3.x. If you bump it, re-verify the
/// `AuthenticationOptions` fields flagged below.
class AppLockService {
  AppLockService._();

  static const String _kEnabled = 'app_lock_enabled';
  static const String _kLastUnlock = 'app_lock_last_unlock';

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kEnabled) ?? false;
    } catch (e) {
      debugPrint('AppLockService.isEnabled error: $e');
      return false;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, value);
      if (!value) {
        await prefs.remove(_kLastUnlock);
      }
    } catch (e) {
      debugPrint('AppLockService.setEnabled error: $e');
    }
  }

  /// Returns true if device supports any form of local auth (biometrics or PIN).
  static Future<bool> isDeviceSupported() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported || canCheck;
    } catch (e) {
      debugPrint('AppLockService.isDeviceSupported error: $e');
      return false;
    }
  }

  /// Prompt the user to authenticate. Returns true when lock is disabled or the
  /// platform cannot authenticate (fail-open so the user is never locked out),
  /// and true on a successful biometric/credential check.
  static Future<bool> authenticate(
      {String reason = 'Unlock SpendSmart to continue'}) async {
    try {
      if (!await isEnabled()) return true;
      if (!await isDeviceSupported()) return true;

      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN/pattern fallback
          stickyAuth: true,
          // TODO: verify against installed version — `useErrorDialogs` exists in
          // local_auth 2.x and defaults to true.
        ),
      );
      if (ok) await _markUnlocked();
      return ok;
    } catch (e) {
      // Platform exception (no enrolled biometrics, unsupported, etc.):
      // fail-open so the app remains usable.
      debugPrint('AppLockService.authenticate error: $e');
      return true;
    }
  }

  static Future<void> _markUnlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastUnlock, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('AppLockService._markUnlocked error: $e');
    }
  }

  /// True if the lock is enabled and more than [timeout] has elapsed since the
  /// last successful unlock (or there has never been one).
  static Future<bool> needsUnlock(Duration timeout) async {
    try {
      if (!await isEnabled()) return false;
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_kLastUnlock);
      if (last == null) return true;
      final elapsed = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(last));
      return elapsed > timeout;
    } catch (e) {
      debugPrint('AppLockService.needsUnlock error: $e');
      return false;
    }
  }
}
