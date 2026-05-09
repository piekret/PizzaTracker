import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig?>((ref) => null);

class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  final String supabaseUrl;
  final String supabaseAnonKey;

  static Future<AppConfig?> load() async {
    final dartDefineConfig = fromEnvironment();
    if (dartDefineConfig != null) {
      return dartDefineConfig;
    }

    try {
      await dotenv.load(fileName: '.env.client');
    } catch (_) {
      return null;
    }

    final rawUrl = dotenv.maybeGet('SUPABASE_URL') ?? '';
    final anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';

    return fromValues(rawUrl: rawUrl, anonKey: anonKey);
  }

  static AppConfig? fromEnvironment() {
    const rawUrl = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    return fromValues(rawUrl: rawUrl, anonKey: anonKey);
  }

  static AppConfig? fromValues({
    required String rawUrl,
    required String anonKey,
  }) {
    if (rawUrl.trim().isEmpty || anonKey.trim().isEmpty) {
      return null;
    }

    return AppConfig(
      supabaseUrl: _normalizeSupabaseUrl(rawUrl),
      supabaseAnonKey: anonKey.trim(),
    );
  }

  static String _normalizeSupabaseUrl(String value) {
    var url = value.trim();

    if (url.endsWith('/rest/v1/')) {
      url = url.substring(0, url.length - '/rest/v1/'.length);
    } else if (url.endsWith('/rest/v1')) {
      url = url.substring(0, url.length - '/rest/v1'.length);
    }

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }
}
