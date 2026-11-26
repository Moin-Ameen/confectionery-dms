import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/base_model.dart';

/// Small key-value settings stored on the phone.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late SharedPreferences _p;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    if ((_p.getString('deviceId') ?? '').isEmpty) {
      await _p.setString('deviceId', newId());
    }
  }

  String get deviceId => _p.getString('deviceId') ?? '';

  String get businessName => _p.getString('businessName') ?? 'My Distribution';
  set businessName(String v) => _p.setString('businessName', v);

  String get businessAddress => _p.getString('businessAddress') ?? '';
  set businessAddress(String v) => _p.setString('businessAddress', v);

  String get businessPhone => _p.getString('businessPhone') ?? '';
  set businessPhone(String v) => _p.setString('businessPhone', v);

  String get invoiceFooter => _p.getString('invoiceFooter') ?? 'Thank you for your business!';
  set invoiceFooter(String v) => _p.setString('invoiceFooter', v);

  String get apiBaseUrl => _p.getString('apiBaseUrl') ?? AppConfig.defaultApiBaseUrl;
  set apiBaseUrl(String v) => _p.setString('apiBaseUrl', v.trim());

  String get apiToken => _p.getString('apiToken') ?? AppConfig.defaultApiToken;
  set apiToken(String v) => _p.setString('apiToken', v.trim());

  int get lastPull => _p.getInt('lastPull') ?? 0;
  set lastPull(int v) => _p.setInt('lastPull', v);

  DateTime? get lastSyncAt {
    final s = _p.getString('lastSyncAt');
    return s == null ? null : DateTime.tryParse(s);
  }

  set lastSyncAt(DateTime? v) => v == null ? _p.remove('lastSyncAt') : _p.setString('lastSyncAt', v.toIso8601String());

  String get sessionUserId => _p.getString('sessionUserId') ?? '';
  set sessionUserId(String v) => _p.setString('sessionUserId', v);

  String get printerMac => _p.getString('printerMac') ?? '';
  set printerMac(String v) => _p.setString('printerMac', v);

  String get printerName => _p.getString('printerName') ?? '';
  set printerName(String v) => _p.setString('printerName', v);

  bool get darkMode => _p.getBool('darkMode') ?? false;
  set darkMode(bool v) => _p.setBool('darkMode', v);

  bool get onDuty => _p.getBool('onDuty') ?? false;
  set onDuty(bool v) => _p.setBool('onDuty', v);
}
