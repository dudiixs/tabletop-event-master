import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class UrlSecurity {
  static const Set<String> _allowedSchemes = {'https', 'http'};

  /// Checks whether a given [rawUrl] is syntactically valid and uses a safe scheme.
  static bool isSafeWebUrl(String? rawUrl) {
    if (rawUrl == null) return false;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;

    // Must have a scheme and it must be either https or http
    if (!uri.hasScheme || !_allowedSchemes.contains(uri.scheme.toLowerCase())) {
      return false;
    }

    // Must have a host (avoids file:/// or javascript: quirks)
    if (uri.host.isEmpty) return false;

    return true;
  }

  /// Safely opens an external URL after validating that its scheme is safe.
  static Future<bool> openSafeUrl(
    BuildContext context,
    String rawUrl, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    if (!isSafeWebUrl(rawUrl)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link inválido ou não seguro para abertura.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    final uri = Uri.parse(rawUrl.trim());
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o link externo.'),
          ),
        );
      }
      return false;
    }
  }
}
