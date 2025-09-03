import 'package:flutter_test/flutter_test.dart';
import 'package:photoframe/Cache.dart';

void main() {
  group('test cache', () {
    test('add and get items', () {
      final cache = Cache<int>(maxSize: 3);
      cache.add(1);
      cache.add(2);
      cache.add(3);
      expect(
        cache.getNextItem(),
        null,
      ); // Should return null since we haven't started getting items
      expect(cache.getPreviousItem(), 2);
      expect(cache.getPreviousItem(), 1);
      expect(cache.getPreviousItem(), null);
      expect(cache.getNextItem(), 2);
      expect(cache.getNextItem(), 3);
      expect(cache.getNextItem(), null);

      cache.add(4);
      expect(cache.length, 3); // Should remove the oldest item (1)
      expect(cache.getPreviousItem(), 3);
    });

    test('reset functionality', () {
      final cache = Cache<int>(maxSize: 2);
      cache.add(1);
      cache.add(2);

      cache.reset();
      expect(cache.getPreviousItem(), null); // Should reset to initial state
    });
  });
}
