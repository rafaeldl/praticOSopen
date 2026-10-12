import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/storage_url_resolver.dart';
import 'package:praticos/widgets/cached_image.dart';

const _botUrl = 'https://storage.googleapis.com/praticos.appspot.com/'
    'tenants/c1/orders/o1/photos/a.jpg';
const _firebaseUrl = 'https://firebasestorage.googleapis.com/v0/b/'
    'praticos.appspot.com/o/tenants%2Fc1%2Fa.jpg?alt=media&token=t';

void main() {
  setUp(StorageUrlResolver.clearCache);

  group('storagePathFromUrl', () {
    test('extracts the path from a storage.googleapis.com URL', () {
      expect(
        StorageUrlResolver.storagePathFromUrl(_botUrl),
        'tenants/c1/orders/o1/photos/a.jpg',
      );
    });

    test('leaves Firebase download URLs alone', () {
      expect(StorageUrlResolver.storagePathFromUrl(_firebaseUrl), isNull);
      expect(StorageUrlResolver.needsResolve(_firebaseUrl), isFalse);
    });

    test('ignores a bucket-only URL and garbage', () {
      expect(
        StorageUrlResolver.storagePathFromUrl(
            'https://storage.googleapis.com/bucket'),
        isNull,
      );
      expect(StorageUrlResolver.storagePathFromUrl(''), isNull);
    });
  });

  group('resolve', () {
    test('asks Firebase Storage for a download URL once per path', () async {
      final asked = <String>[];
      StorageUrlResolver.getDownloadUrl = (path) async {
        asked.add(path);
        return 'https://fresh/$path';
      };

      expect(await StorageUrlResolver.resolve(_botUrl),
          'https://fresh/tenants/c1/orders/o1/photos/a.jpg');
      await StorageUrlResolver.resolve(_botUrl);
      expect(asked, ['tenants/c1/orders/o1/photos/a.jpg']);
    });

    test('returns usable URLs unchanged', () async {
      StorageUrlResolver.getDownloadUrl = (_) => throw StateError('no');
      expect(await StorageUrlResolver.resolve(_firebaseUrl), _firebaseUrl);
    });

    test('returns null when the file cannot be resolved', () async {
      StorageUrlResolver.getDownloadUrl = (_) async => throw Exception('404');
      expect(await StorageUrlResolver.resolve(_botUrl), isNull);
    });
  });

  testWidgets('CachedImage shows the error widget when resolve fails',
      (tester) async {
    StorageUrlResolver.getDownloadUrl = (_) async => throw Exception('404');
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: CachedImage(
        imageUrl: _botUrl,
        width: 88,
        height: 88,
        errorWidget: Text('erro'),
        placeholder: Text('carregando'),
      ),
    ));
    expect(find.text('carregando'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('erro'), findsOneWidget);
  });
}
