import 'package:dartssh2/dartssh2.dart';
import 'package:googleapis/drive/v2.dart' as gApi;
import 'dart:typed_data';
import 'dart:convert';
import 'package:googleapis/drive/v2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

final acceptedFormats = [
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

class SavedConnection {
  final String name;
  final String type;
  final String host;
  final int port;
  final String username;
  final String password;
  final String rootPath;
  final int duration;
  final int imageCacheSize;

  SavedConnection({
    required this.name,
    required this.type,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.rootPath,
    required this.duration,
    required this.imageCacheSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'rootPath': rootPath,
      'duration': duration,
      'imageCacheSize': imageCacheSize,
    };
  }

  factory SavedConnection.fromJson(Map<String, dynamic> json) {
    return SavedConnection(
      name: json['name'],
      type: json['type'],
      host: json['host'],
      port: json['port'],
      username: json['username'],
      password: json['password'],
      rootPath: json['rootPath'],
      duration: json['duration'],
      imageCacheSize: json['imageCacheSize'],
    );
  }
}

abstract class ConnectionModule {
  Future<void> init();
  Future<List<String>> getPathsInFolder(String path);
  void disconnect();
  Future<Uint8List> open(String path);
}

class SSHconnection extends ConnectionModule {
  final String host;
  final String password;
  final int port;
  final String username;
  late SftpClient sftp;
  late SSHSocket socket;
  late SSHClient client;
  SSHconnection(this.host, this.port, this.username, this.password);

  @override
  Future<void> init() async {
    socket = await SSHSocket.connect(host, port);
    client = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => password,
    );
    sftp = await client.sftp();
  }

  @override
  Future<List<String>> getPathsInFolder(String path) async {
    final loadTargetPathCommand = 'cd $path && find "\$(pwd)" -type f';
    final result = await client.run(loadTargetPathCommand, stderr: false);
    final returnedPaths = utf8.decode(result).split("\\n").where((path) {
      final trimmedPath = path.trim();
      if (trimmedPath.isEmpty) return false;
      return true;
    }).toList();
    final allPaths = returnedPaths.where((path) {
      final fileExtension = p.extension(path).toLowerCase();
      return acceptedFormats.contains(fileExtension);
    }).toList();
    return allPaths;
  }

  @override
  void disconnect() {
    sftp.close();
    client.close();
  }

  @override
  Future<Uint8List> open(String path) async {
    final file = await sftp.open(path);
    return await file.readBytes();
  }
}

class GDconnection extends ConnectionModule {
  final scopes = [DriveApi.driveFileScope];
  DriveApi? _driveApi;

  void _reset() {
    _driveApi = null;
  }

  @override
  Future<void> init() async {
    final signIn = GoogleSignIn.instance;
    await signIn.signOut();
    await signIn.initialize(
      clientId:
          "639070093214-ldpi0q4eb0pvkskl8s5r7av68lsh26e6.apps.googleusercontent.com",
      serverClientId:
          "639070093214-m8pc58cn8vqr9qqjbg67j9isvi7i7ktd.apps.googleusercontent.com",
    );

    // First try lightweight authentication (cached sign-in)
    GoogleSignInAccount? user = await signIn.attemptLightweightAuthentication();

    if (user != null) {
      await _handleUser(user);
    } else {
      throw Exception("User cancelled Google Sign-In or failed to login");
    }
  }

  Future<void> _handleUser(GoogleSignInAccount user) async {
    await _getGDrive(user);
  }

  Future<void> _getGDrive(GoogleSignInAccount user) async {
    final authorization = await user.authorizationClient.authorizationForScopes(
      scopes,
    );
    if (authorization == null) {
      throw Exception("Authorization failed");
    }
    final authenticatedClient = authorization.authClient(scopes: scopes);
    _driveApi = gApi.DriveApi(authenticatedClient);
    if (_driveApi == null) {
      throw Exception("Failed to create Drive API client");
    }
  }

  @override
  void disconnect() {
    GoogleSignIn.instance.signOut();
    _reset();
  }

  // get a list of file IDs.
  @override
  Future<List<String>> getPathsInFolder(String path) async {
    // Create query to filter for image files
    final query = "mimeType contains 'image/'";

    final found = await _driveApi?.files.list(
      q: query,
      includeItemsFromAllDrives: true,
      supportsAllDrives: true,
    );
    final List<File> files = found?.items ?? [];
    return files
        .where((file) {
          final extension = file.fileExtension?.toLowerCase() ?? '';
          return acceptedFormats.contains('.$extension') &&
              file.id != null &&
              file.id!.isNotEmpty;
        })
        .map((file) => file.id!)
        .toList();
  }

  // path is the file ID
  @override
  Future<Uint8List> open(String path) async {
    final file =
        await _driveApi?.files.get(
              path,
              downloadOptions: gApi.DownloadOptions.fullMedia,
            )
            as gApi.Media?;

    if (file?.stream == null) {
      throw Exception('Failed to get file stream');
    }

    // Collect all bytes from the stream
    final List<int> bytes = [];
    await for (final chunk in file!.stream) {
      bytes.addAll(chunk);
    }

    return Uint8List.fromList(bytes);
  }
}
