import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  Map<String, dynamic> _imageMetadata = {};

  // Zoom and pan state
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  Offset _startOffset = Offset.zero;
  double _startScale = 1.0;
  Offset _scaleStartPosition = Offset.zero;
  Offset _currentFocalPoint = Offset.zero;
  bool _showImageDetails = false;

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

  Future<void> _extractImageMetadata(Uint8List imageData, String path) async {
    try {
      final codec = await ui.instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Get file size
      final fileSizeKB = (imageData.length / 1024).round();
      final fileSizeMB = (fileSizeKB / 1024);

      // Extract filename from path
      final filename = path.split('/').last;
      final fileExtension = filename.contains('.')
          ? filename.split('.').last.toUpperCase()
          : 'Unknown';

      _imageMetadata = {
        'filename': filename,
        'path': path,
        'width': image.width,
        'height': image.height,
        'aspectRatio': (image.width / image.height).toStringAsFixed(2),
        'fileSize': fileSizeMB >= 1
            ? '${fileSizeMB.toStringAsFixed(2)} MB'
            : '$fileSizeKB KB',
        'format': fileExtension,
        'resolution': '${image.width} × ${image.height}',
      };

      image.dispose();
    } catch (e) {
      _imageMetadata = {
        'filename': path.split('/').last,
        'path': path,
        'error': 'Could not extract metadata',
      };
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

      _extractImageMetadata(content, path);

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
      onTap: () {
        if (!isPlaying && _scale <= 1) {
          setState(() {
            _showImageDetails = !_showImageDetails;
          });
        }
      },
      onDoubleTapDown: (details) {
        // detect the double taps from left or right.
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
      onScaleStart: (details) {
        if (!isPlaying) {
          _startFocalPoint = details.focalPoint;
          _startOffset = _offset;
          _startScale = _scale;
          _scaleStartPosition = details.focalPoint;
          _currentFocalPoint = details.focalPoint;
        }
      },
      onScaleUpdate: (details) {
        if (!isPlaying) {
          // for detecting swipe
          _currentFocalPoint = details.focalPoint; // Track current focal point
          setState(() {
            // for zoom
            _scale = (_startScale * details.scale).clamp(1.0, 4.0);

            // The whole if-block is for panning.
            if (_scale > 1.0) {
              final focalPointDelta = details.focalPoint - _startFocalPoint;
              final desiredOffset = _startOffset + focalPointDelta / _scale;

              // Constrain offset to prevent over-panning
              final screenSize = MediaQuery.of(context).size;
              final maxOffset = screenSize.width * (_scale - 1) / (2 * _scale);
              _offset = Offset(
                desiredOffset.dx.clamp(-maxOffset, maxOffset),
                desiredOffset.dy.clamp(-maxOffset, maxOffset),
              );
            } else {
              resetImageSize();
            }
            // as long as it zoom or pan, the detail view should be hidden.
            _showImageDetails = false;
          });
        }
      },
      // it will be called when swiping or zooming.
      onScaleEnd: (details) {
        if (!isPlaying && _scale <= 1.0) {
          // Check for left-to-right swipe to resume playing
          final screenWidth = MediaQuery.of(context).size.width;
          final swipeDistance = _currentFocalPoint.dx - _scaleStartPosition.dx;
          final swipeThreshold = screenWidth * 0.2; // 20% of screen width

          if (swipeDistance > swipeThreshold) {
            isPlaying = true;
            _showImageDetails = false;
            // nextScheduler will call setState.
            nextScheduler();
          }

          // when zooming out to scale 1 or swiping
          setState(() {
            resetImageSize();
          });
        }
      },
      child: Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        child: _createImageNonInteractViewer(),
      ),
    );
  }

  void resetImageSize() {
    _scale = 1.0;
    _offset = Offset.zero;
  }

  Widget? _createImageNonInteractViewer() {
    if (image == null) {
      return const CircularProgressIndicator();
    }

    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        Transform(
          transform: Matrix4.identity()
            ..scale(_scale)
            ..translate(_offset.dx, _offset.dy),
          alignment: Alignment.center,
          child: image!,
        ),
        if (_showImageDetails) _buildImageDetailsOverlay(),
      ],
    );
  }

  Widget _buildImageDetailsOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Image Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_imageMetadata.isNotEmpty) ...[
              _buildMetadataRow('Filename', _imageMetadata['filename'] ?? ''),
              _buildMetadataRow('Format', _imageMetadata['format'] ?? ''),
              _buildMetadataRow(
                'Resolution',
                _imageMetadata['resolution'] ?? '',
              ),
              _buildMetadataRow(
                'Aspect Ratio',
                _imageMetadata['aspectRatio'] ?? '',
              ),
              _buildMetadataRow('File Size', _imageMetadata['fileSize'] ?? ''),
              const SizedBox(height: 8),
              _buildMetadataRow(
                'Path',
                _imageMetadata['path'] ?? '',
                isPath: true,
              ),
              if (_imageMetadata['error'] != null)
                _buildMetadataRow(
                  'Error',
                  _imageMetadata['error'],
                  isError: true,
                ),
            ] else
              const Text(
                'Loading metadata...',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(
    String label,
    String value, {
    bool isPath = false,
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: isError ? Colors.red : Colors.grey[300],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? Colors.red : Colors.white,
                fontSize: 14,
                fontFamily: isPath ? 'monospace' : null,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  void _onDoubleTapLeft() {
    final previousItem = cache.getPreviousItem();
    if (previousItem != null) {
      _cleanTimer();
      setState(() {
        image = Image.memory(previousItem);
        resetImageSize();
      });
    }
  }

  void _onDoubleTapRight() {
    final nextItem = cache.getNextItem();
    if (nextItem != null) {
      _cleanTimer();
      setState(() {
        image = Image.memory(nextItem);
        resetImageSize();
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
