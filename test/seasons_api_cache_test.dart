import 'package:Mirarr/seriesPage/function/seasons_api_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(clearSeasonsApiCache);

  test('concurrent callers share one in-flight future', () async {
    var calls = 0;
    Future<int> load() {
      return cachedSeasonsApiCall('shared', () async {
        calls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 42;
      });
    }

    final results = await Future.wait([load(), load(), load()]);
    expect(results, [42, 42, 42]);
    expect(calls, 1);
  });

  test('failed futures are not cached', () async {
    var calls = 0;
    Future<int> load() {
      return cachedSeasonsApiCall('fail', () async {
        calls += 1;
        throw StateError('boom');
      });
    }

    await expectLater(load(), throwsStateError);
    await expectLater(load(), throwsStateError);
    expect(calls, 2);
  });

  test('cache evicts oldest entries beyond the LRU limit', () async {
    for (var i = 0; i < 55; i++) {
      await cachedSeasonsApiCall('key_$i', () async => i);
    }

    expect(seasonsApiCache.length, 50);
    expect(seasonsApiCache.containsKey('key_0'), isFalse);
    expect(seasonsApiCache.containsKey('key_4'), isFalse);
    expect(seasonsApiCache.containsKey('key_5'), isTrue);
    expect(seasonsApiCache.containsKey('key_54'), isTrue);
  });
}
