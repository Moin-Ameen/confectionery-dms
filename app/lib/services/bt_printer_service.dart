import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'pdf_service.dart';
import 'settings_service.dart';

class BtDevice {
  final String name;
  final String mac;
  BtDevice(this.name, this.mac);
}

/// Bluetooth thermal printer (58mm = 32 chars, 80mm = 48 chars) using raw ESC/POS.
class BtPrinterService {
  BtPrinterService._();
  static final BtPrinterService instance = BtPrinterService._();

  int width = 32;

  Future<void> _permissions() async {
    try {
      await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    } catch (_) {}
  }

  Future<List<BtDevice>> pairedDevices() async {
    await _permissions();
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) return [];
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list.map((d) => BtDevice(d.name, d.macAdress)).toList();
  }

  Future<String?> printDoc(PrintDoc d) async {
    final s = SettingsService.instance;
    if (s.printerMac.isEmpty) return 'Select a Bluetooth printer in Settings first';
    await _permissions();
    var connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      connected = await PrintBluetoothThermal.connect(macPrinterAddress: s.printerMac);
    }
    if (!connected) return 'Printer not connected';
    final ok = await PrintBluetoothThermal.writeBytes(_receipt(d));
    return ok ? null : 'Print failed';
  }

  // ---------------- ESC/POS ----------------
  static const _esc = 0x1B;
  static const _gs = 0x1D;

  List<int> _receipt(PrintDoc d) {
    final s = SettingsService.instance;
    final b = <int>[];
    void cmd(List<int> c) => b.addAll(c);
    void text(String t) => b.addAll(latin1.encode(_ascii(t)));
    void line(String t) => text('$t\n');
    void center(bool on) => cmd([_esc, 0x61, on ? 1 : 0]);
    void bold(bool on) => cmd([_esc, 0x45, on ? 1 : 0]);
    void big(bool on) => cmd([_gs, 0x21, on ? 0x11 : 0x00]);
    final sep = '-' * width;

    cmd([_esc, 0x40]); // init
    center(true);
    bold(true);
    big(true);
    line(s.businessName);
    big(false);
    bold(false);
    if (s.businessAddress.isNotEmpty) line(s.businessAddress);
    if (s.businessPhone.isNotEmpty) line(s.businessPhone);
    line(sep);
    bold(true);
    line('${d.title} ${d.number}');
    bold(false);
    line(DateFormat('dd-MM-yyyy hh:mm a').format(d.date));
    center(false);
    line(sep);
    for (final p in d.partyLines) {
      line(p);
    }
    if (d.partyLines.isNotEmpty) line(sep);

    // rows: first col name on its own line, rest right aligned
    for (final r in d.rows) {
      if (r.isEmpty) continue;
      line(r.first);
      if (r.length > 1) {
        final rest = r.sublist(1).join('  ');
        line(_right(rest));
      }
    }
    line(sep);
    for (final t in d.totals) {
      line(_pair(t.key, t.value));
    }
    line(sep);
    if (d.note.isNotEmpty) line(d.note);
    center(true);
    line(s.invoiceFooter);
    line('Powered by CASHLIFYPOS');
    center(false);
    text('\n\n\n');
    cmd([_gs, 0x56, 0x00]); // cut
    return b;
  }

  String _ascii(String s) => s.replaceAll(RegExp(r'[^\x20-\x7E\n]'), '');

  String _right(String s) => s.length >= width ? s : ' ' * (width - s.length) + s;

  String _pair(String l, String r) {
    final space = width - l.length - r.length;
    if (space < 1) return '$l $r';
    return l + ' ' * space + r;
  }
}
