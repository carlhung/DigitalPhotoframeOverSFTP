import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'dart:convert';

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
    final allPaths = utf8.decode(result).split("\n").where((path) {
      final trimmedPath = path.trim();
      if (trimmedPath.isEmpty) return false;
      return true;
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
