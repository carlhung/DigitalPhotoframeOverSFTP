import 'dart:math';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:path/path.dart';
import 'dart:io' show Platform;

import 'package:photoframe/helpers.dart';

class PhotoframeController extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final SftpClient sftp;
  final SSHClient client;
  final List<String> imagePaths;
  final Duration duration;

  PhotoframeController({
    super.key,
    required this.navigatorKey,
    required this.sftp,
    required this.client,
    required this.imagePaths,
    required this.duration,
  });

  @override
  State<PhotoframeController> createState() => _PhotoframeControllerState();
}

class _PhotoframeControllerState extends State<PhotoframeController> {
  Image? image;
  final random = Random();

  void keepSreen(bool value) {
    if (Platform.isAndroid || Platform.isIOS) {
      if (value) {
        KeepScreenOn.turnOn();
      } else {
        KeepScreenOn.turnOff();
      }
    }
  }

  _PhotoframeControllerState() {
    keepSreen(true);
  }

  @override
  void initState() {
    super.initState();
    nextScheduler();
  }

  Future<Image?> loadImage(String path) async {
    try {
      final file = await widget.sftp.open(path);
      final content = await file.readBytes();

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
      body: Center(child: image ?? const CircularProgressIndicator()),
    );
  }

  void disconnect() {
    widget.sftp.close(); // optional

    widget.client.close();
  }

  Future<void> nextScheduler() async {
    while (true) {
      final path = widget.imagePaths[random.nextInt(widget.imagePaths.length)];
      final image = await loadImage(path);
      if (image != null) {
        setState(() {
          this.image = image;
          Future.delayed(widget.duration, () async {
            await nextScheduler();
          });
        });
        return;
      }
    }
  }

  @override
  void dispose() {
    keepSreen(false);
    disconnect();
    super.dispose();
  }
}
