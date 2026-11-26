import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'settings_service.dart';

class ReleaseInfo {
  final int build;
  final String version;
  final String notes;
  final int size;
  ReleaseInfo(this.build, this.version, this.notes, this.size);
}

/// In-app update: checks the server for a newer APK, downloads it and opens the Android installer.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  final _s = SettingsService.instance;
  int? _currentBuild;
  String _currentVersion = '';

  Future<int> currentBuild() async {
    if (_currentBuild != null) return _currentBuild!;
    final info = await PackageInfo.fromPlatform();
    _currentBuild = int.tryParse(info.buildNumber) ?? 0;
    _currentVersion = info.version;
    return _currentBuild!;
  }

  Future<String> currentVersionLabel() async {
    final b = await currentBuild();
    return '$_currentVersion (build $b)';
  }

  String _url(String path) {
    var base = _s.apiBaseUrl;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return '$base$path';
  }

  Map<String, String> get _headers => {if (_s.apiToken.isNotEmpty) 'Authorization': 'Bearer ${_s.apiToken}'};

  /// Returns the newer release, or null if up to date / offline.
  Future<ReleaseInfo?> check() async {
    if (_s.apiBaseUrl.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(_url('/api/app/latest')), headers: _headers).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final build = (m['build'] as num?)?.toInt() ?? 0;
      if (build <= await currentBuild()) return null;
      return ReleaseInfo(build, '${m['version'] ?? ''}', '${m['notes'] ?? ''}', (m['size'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return null;
    }
  }

  /// Downloads the APK (reports 0..1 progress) and returns the file path.
  Future<String> download(ReleaseInfo r, void Function(double) onProgress) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/update-${r.build}.apk');
    if (await file.exists() && r.size > 0 && await file.length() == r.size) {
      onProgress(1);
      return file.path;
    }
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(_url('/api/app/download')))..headers.addAll(_headers);
      final res = await client.send(req).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) throw Exception('Download failed (${res.statusCode})');
      final total = res.contentLength ?? r.size;
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.close();
      if (r.size > 0 && got != r.size) throw Exception('Download incomplete, try again');
      return file.path;
    } finally {
      client.close();
    }
  }

  /// Opens the Android "Install / Update" screen. Returns an error message or null.
  Future<String?> install(String path) async {
    final r = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
    if (r.type == ResultType.done) return null;
    if (r.type == ResultType.permissionDenied) {
      return 'Allow "Install unknown apps" for this app in phone settings, then try again';
    }
    return r.message;
  }
}
