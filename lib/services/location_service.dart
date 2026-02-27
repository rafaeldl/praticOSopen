import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Service for map integration
class LocationService {
  /// Open location in external maps app
  Future<void> openInMaps({double? lat, double? lng, String? address}) async {
    Uri uri;

    if (lat != null && lng != null) {
      if (!kIsWeb && Platform.isIOS) {
        uri = Uri.parse('https://maps.apple.com/?q=$lat,$lng');
      } else {
        // Android, web, and other platforms use Google Maps URL
        uri = kIsWeb
            ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng')
            : Uri.parse('geo:$lat,$lng?q=$lat,$lng');
      }
    } else if (address != null && address.isNotEmpty) {
      final encoded = Uri.encodeComponent(address);
      if (!kIsWeb && Platform.isIOS) {
        uri = Uri.parse('https://maps.apple.com/?q=$encoded');
      } else {
        uri = kIsWeb
            ? Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded')
            : Uri.parse('geo:0,0?q=$encoded');
      }
    } else {
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
