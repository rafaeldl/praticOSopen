import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/receive_share_service.dart';
import 'package:praticos/services/received_share.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

// iOS Share Extension: the Dart side and the native config it depends on.
void main() {
  group('receiveShareSupported', () {
    test('Android and iOS receive shares', () {
      expect(receiveShareSupported(isWeb: false, operatingSystem: 'android'),
          isTrue);
      expect(
          receiveShareSupported(isWeb: false, operatingSystem: 'ios'), isTrue);
    });

    test('web and desktop do not', () {
      expect(receiveShareSupported(isWeb: true, operatingSystem: 'ios'),
          isFalse);
      expect(receiveShareSupported(isWeb: false, operatingSystem: 'macos'),
          isFalse);
      expect(receiveShareSupported(isWeb: false, operatingSystem: ''),
          isFalse);
    });
  });

  group('normalizeSharedPath', () {
    test('plain paths are unchanged', () {
      const p = '/private/var/mobile/Containers/Shared/AppGroup/X/a%20b.pdf';
      expect(normalizeSharedPath(p), p);
    });

    test('file URIs become decoded paths', () {
      expect(
          normalizeSharedPath(
              'file:///private/var/mobile/Containers/Shared/AppGroup/X/Nota%20fiscal.pdf'),
          '/private/var/mobile/Containers/Shared/AppGroup/X/Nota fiscal.pdf');
    });
  });

  test('isShareExtensionCopy only matches the App Group container', () {
    expect(
        isShareExtensionCopy(
            '/private/var/mobile/Containers/Shared/AppGroup/ABC/IMG_1.jpeg'),
        isTrue);
    expect(isShareExtensionCopy('/var/mobile/Media/DCIM/100APPLE/IMG_1.HEIC'),
        isFalse);
    expect(isShareExtensionCopy('/data/user/0/br.com.rafsoft.praticos/a.jpg'),
        isFalse);
  });

  test('iOS payload: photos and PDFs routed, text and URLs dropped', () {
    // Shape sent by the iOS plugin over the channel (JSON list).
    const group = '/private/var/mobile/Containers/Shared/AppGroup/ABC';
    final json = jsonEncode([
      {'path': '$group/IMG_0001.HEIC', 'mimeType': 'image/heic', 'type': 'image'},
      {'path': 'file://$group/Or%C3%A7amento.pdf', 'mimeType': 'application/pdf', 'type': 'file'},
      {'path': '$group/planilha.xlsx', 'mimeType': 'application/vnd.ms-excel', 'type': 'file'},
      {'path': 'Olha isso', 'mimeType': 'text/plain', 'type': 'text'},
      {'path': 'https://example.com', 'type': 'url'},
    ]);
    final media = (jsonDecode(json) as List)
        .map((m) => SharedMediaFile.fromMap(m as Map<String, dynamic>))
        .toList();

    final files = ReceiveShareService.filesFromShared(media);
    expect(files.map((f) => f.fileName),
        ['IMG_0001.HEIC', 'Orçamento.pdf', 'planilha.xlsx']);

    final batch = ReceivedBatch(files);
    expect(batch.photos.map((f) => f.fileName), ['IMG_0001.HEIC']);
    expect(batch.pdfs.map((f) => f.path), ['$group/Orçamento.pdf']);
  });

  group('iOS project config', () {
    const groupId = 'group.br.com.rafsoft.praticos';
    String read(String path) => File(path).readAsStringSync();

    test('extension accepts images and PDFs', () {
      final plist = read('ios/ShareExtension/Info.plist');
      expect(plist, contains('com.apple.share-services'));
      expect(plist, contains('"public.image"'));
      expect(plist, contains('"com.adobe.pdf"'));
      expect(plist, contains('<key>AppGroupId</key>'));
      expect(plist, contains(r'$(FLUTTER_BUILD_NUMBER)'));
    });

    test('app and extension share the same App Group', () {
      expect(read('ios/Runner/Runner.entitlements'), contains(groupId));
      expect(read('ios/ShareExtension/ShareExtension.entitlements'),
          contains(groupId));
      final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
      expect(pbx, contains('CUSTOM_GROUP_ID = $groupId;'));
      expect(pbx,
          contains('PRODUCT_BUNDLE_IDENTIFIER = br.com.rafsoft.praticos.ShareExtension;'));
    });

    test('app opens from the extension (URL scheme + group id)', () {
      for (final f in ['ios/Runner/Info-Debug.plist', 'ios/Runner/Info-Release.plist']) {
        final plist = read(f);
        expect(plist, contains(r'ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)'),
            reason: f);
        expect(plist, contains('<key>AppGroupId</key>'), reason: f);
      }
    });

    test('extension embedded before Thin Binary', () {
      final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
      final runnerPhases = RegExp(r'/\* Runner \*/ = \{\s*isa = PBXNativeTarget;[\s\S]*?buildPhases = \(([\s\S]*?)\);')
          .firstMatch(pbx)!
          .group(1)!;
      final embed = runnerPhases.indexOf('Embed Foundation Extensions');
      final thin = runnerPhases.indexOf('Thin Binary');
      expect(embed, greaterThan(-1));
      expect(embed, lessThan(thin));
    });

    test('match signs the extension too', () {
      expect(read('ios/fastlane/Matchfile'),
          contains('br.com.rafsoft.praticos.ShareExtension'));
    });
  });
}
