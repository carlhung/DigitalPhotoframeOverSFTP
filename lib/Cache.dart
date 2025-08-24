final class Cache<T> {
  final int maxSize;
  final List<T> _cache = [];
  int currentIndex = 0;
  int get length => _cache.length;
  bool _isStartedGettingItems = false;

  Cache({this.maxSize = 10});

  void add(T item) {
    _isStartedGettingItems = false;
    _cache.add(item);
    if (_cache.length > maxSize) {
      _cache.removeAt(0);
    }
  }

  T? getPreviousItem() {
    if (_cache.isEmpty) return null;
    if (!_isStartedGettingItems) {
      _isStartedGettingItems = true;
      currentIndex = _cache.length - 1 - 1;
      if (currentIndex < 0) {
        currentIndex = 0;
        return null;
      }
      return _cache[currentIndex];
    } else {
      currentIndex--;
      if (currentIndex < 0) {
        currentIndex = 0;
        return null;
      }
      return _cache[currentIndex];
    }
  }

  T? getNextItem() {
    if (_cache.isEmpty) return null;
    if (!_isStartedGettingItems) {
      _isStartedGettingItems = true;
      currentIndex = _cache.length - 1;
      return null;
    } else {
      currentIndex++;
      if (currentIndex >= _cache.length) {
        currentIndex = _cache.length - 1;
        return null;
      }
      return _cache[currentIndex];
    }
  }

  void reset() {
    _isStartedGettingItems = false;
    currentIndex = 0;
  }
}
