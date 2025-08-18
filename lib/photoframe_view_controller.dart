import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:photoframe/connection_view_controller.dart';
import 'dart:io' show Platform;

import 'package:photoframe/helpers.dart';

class PhotoframeController extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final ConnectionModule connection;
  final List<String> imagePaths;
  final Duration duration;
  final int imageCacheSize;

  const PhotoframeController({
    super.key,
    required this.navigatorKey,
    required this.connection,
    required this.imagePaths,
    required this.duration,
    required this.imageCacheSize,
  });

  @override
  State<PhotoframeController> createState() => _PhotoframeControllerState();
}

class _PhotoframeControllerState extends State<PhotoframeController>
    with WidgetsBindingObserver {
  Image? image;
  Cache<Uint8List> cache = Cache<Uint8List>(maxSize: 10);
  final random = Random();
  Timer? _timer;
  bool isPlaying = true;

  void keepSreen(bool value) {
    if (Platform.isAndroid || Platform.isIOS) {
      if (value) {
        KeepScreenOn.turnOn();
      } else {
        KeepScreenOn.turnOff();
      }
    }
  }

  void _cleanTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  _PhotoframeControllerState() {
    keepSreen(true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cache = Cache<Uint8List>(maxSize: widget.imageCacheSize);
    nextScheduler();
  }

  Future<Image?> loadImage(String path) async {
    try {
      final content = await widget.connection.open(path);
      cache.add(content);
      return Image.memory(content);
    } catch (e) {
      final context = widget.navigatorKey.currentContext;
      if (context != null && context.mounted) showErrorOnSnackBar(context, e);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // appBar: AppBar(
      //   backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      //   title: const Text("photoframe"),
      // ),
      body: _body(),
    );
  }

  Widget _body() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (details) {
        final width = MediaQuery.of(context).size.width;
        final dx = details.localPosition.dx;
        if (dx < width / 2) {
          // Double-tap on the left side
          _onDoubleTapLeft();
        } else {
          // Double-tap on the right side
          _onDoubleTapRight();
        }
        isPlaying = false;
      },
      onPanEnd: (details) {
        if (!isPlaying) {
          isPlaying = true;
          nextScheduler();
        }
      },
      child: Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        child: _createImageNonInteractViewer(),
        // child: _timer == null
        //     ? _createImageInteractViewer()
        //     : _createImageNonInteractViewer(),
      ),
    );
  }

  Widget? _createImageNonInteractViewer() {
    return image ?? const CircularProgressIndicator();
  }

  // Widget? _createImageInteractViewer() {
  //   return InteractiveViewer(
  //     panEnabled: false,
  //     child: image ?? const CircularProgressIndicator(),
  //   );
  // }

  void _onDoubleTapLeft() {
    final previousItem = cache.getPreviousItem();
    if (previousItem != null) {
      _cleanTimer();
      setState(() {
        image = Image.memory(previousItem);
      });
    }
  }

  void _onDoubleTapRight() {
    final nextItem = cache.getNextItem();
    if (nextItem != null) {
      _cleanTimer();
      setState(() {
        image = Image.memory(nextItem);
      });
    }
  }

  void disconnect() {
    widget.connection.disconnect();
  }

  Future<void> nextScheduler() async {
    while (true) {
      final path = widget.imagePaths[random.nextInt(widget.imagePaths.length)];
      final image = await loadImage(path);
      if (image != null) {
        setState(() {
          this.image = image;
          _timer = Timer(widget.duration, () async {
            _cleanTimer();
            await nextScheduler();
          });
        });
        return;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App going to background
        _handleAppPaused();
        break;
      // case AppLifecycleState.resumed:
      //   // App coming back to foreground
      //   _handleAppResumed();
      //   break;
      default:
        break;
    }
  }

  void _handleAppPaused() {
    // Keep SSH alive or save state
    // sshManager.startHeartbeat();
    final context = widget.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.pop(context);
    }
  }

  // void _handleAppResumed() {
  //   // Reconnect if needed
  //   // if (!sshClient.isConnected) {
  //   //   sshClient.reconnect();
  //   // }
  // }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    keepSreen(false);
    disconnect();
    _cleanTimer();
    super.dispose();
  }
}

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
