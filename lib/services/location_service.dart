import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Service for map integration
class LocationService {
  /// Open location in external maps app
  Future<void> openInMaps({double? lat, double? lng, String? address}) async {
    Uri uri;

    if (lat != null && lng != null) {
      if (Platform.isIOS) {
        uri = Uri.parse('https://maps.apple.com/?q=$lat,$lng');
      } else {
        uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
      }
    } else if (address != null && address.isNotEmpty) {
      final encoded = Uri.encodeComponent(address);
      if (Platform.isIOS) {
        uri = Uri.parse('https://maps.apple.com/?q=$encoded');
      } else {
        uri = Uri.parse('geo:0,0?q=$encoded');
      }
    } else {
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
