import 'dart:convert';
import 'dart:math';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:path/path.dart';
import 'dart:io' show Platform;

class PhotoframeController extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const PhotoframeController({super.key, required this.navigatorKey});

  @override
  State<PhotoframeController> createState() => _PhotoframeControllerState();
}

class _PhotoframeControllerState extends State<PhotoframeController> {
  final internalIP = '192.168.1.9';
  final externalIP = 'carlhung.asuscomm.com';
  final internalPort = 22;
  final externalPort = 2222;
  final username = 'carlhung';
  final password = 'C07afebr1982l';
  late SSHClient client;
  List<String> imagePaths = [];
  Image? image;
  final interval = const Duration(seconds: 5);
  final random = Random();
  late SftpClient sftp;
  final loadTargetPathCommand =
      'cd externalDisk/myDoc/Pictures/photos && find "\$(pwd)" -type f';
  final List<String> acceptedFormats = [
    "jpg",
    "png",
    "jpeg",
    "gif",
    "webp",
    "bmp",
    "wbmp",
    "heic",
    "heif",
  ].map((str) => '.${str.toLowerCase()}').toList();

  _PhotoframeControllerState() {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        KeepScreenOn.turnOn();
      }
    } catch (e) {
      final context = widget.navigatorKey.currentContext;
      if (context != null && context.mounted) showErrorOnSnackBar(context, e);
    }
  }

  @override
  void initState() {
    super.initState();
    _initClientAndLoadImages().then((_) async {
      await nextScheduler();
    });
  }

  Future<void> _initClientAndLoadImages() async {
    for (final elm in [
      (internalIP, internalPort),
      (externalIP, externalPort),
    ]) {
      try {
        client = await getClient(elm.$1, elm.$2);
        sftp = await client.sftp();
        final paths = await loadAllImagePaths(client);
        imagePaths = paths;
        return;
      } catch (e) {
        continue;
      }
    }
    throw Exception('None of the IP address works.');
  }

  Future<SSHClient> getClient(String ip, int port) async {
    final socket = await SSHSocket.connect(ip, port);
    return SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => password,
    );
  }

  Future<List<String>> loadAllImagePaths(SSHClient client) async {
    final result = await client.run(loadTargetPathCommand, stderr: false);
    final allPaths = utf8
        .decode(result)
        .split("\n")
        .where((path) => path.trim().isNotEmpty)
        .toList();
    allPaths.shuffle();
    return allPaths;
  }

  Future<Image?> loadImage(String path) async {
    try {
      final file = await sftp.open(path);
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
    sftp.close(); // optional
    client.close();
  }

  void showErrorOnSnackBar(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: interval, content: Text('error: $error')),
    );
  }

  Future<void> nextScheduler() async {
    while (true) {
      final path = imagePaths[random.nextInt(imagePaths.length)];
      final exten = extension(path).toLowerCase();
      if (acceptedFormats.contains(exten)) {
        final image = await loadImage(path);
        if (image != null) {
          setState(() {
            this.image = image;
            Future.delayed(interval, () {
              nextScheduler();
            });
          });
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
