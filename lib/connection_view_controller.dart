import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:photoframe/helpers.dart';
import 'package:photoframe/photoframe_view_controller.dart';
import 'package:photoframe/ssh_connection_form.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:typed_data';

class ConnectionFormWidget extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const ConnectionFormWidget({super.key, required this.navigatorKey});

  @override
  State<ConnectionFormWidget> createState() => _ConnectionFormWidgetState();
}

class _ConnectionFormWidgetState extends State<ConnectionFormWidget> {
  List<SavedConnection> _savedConnections = [];
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadSavedConnections();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSavedConnections() async {
    final connectionsString = await _secureStorage.read(
      key: 'saved_connections',
    );

    if (connectionsString != null) {
      final connectionsJson = List<String>.from(
        jsonDecode(connectionsString) ?? [],
      );

      setState(() {
        _savedConnections = connectionsJson
            .map((json) => SavedConnection.fromJson(jsonDecode(json)))
            .toList();
      });
    } else {
      setState(() {
        _savedConnections = [];
      });
    }
  }

  Future<void> _saveConnections() async {
    final connectionsJson = _savedConnections
        .map((connection) => jsonEncode(connection.toJson()))
        .toList();
    await _secureStorage.write(
      key: 'saved_connections',
      value: jsonEncode(connectionsJson),
    );
  }

  Future<void> _addConnection(SavedConnection connection) async {
    setState(() {
      _savedConnections.add(connection);
    });
    await _saveConnections();
  }

  Future<void> _deleteConnection(int index) async {
    setState(() {
      _savedConnections.removeAt(index);
    });
    await _saveConnections();
  }

  Future<void> _connectToSavedConnection(
    SavedConnection savedConnection,
  ) async {
    try {
      final connection = SSHconnection(
        savedConnection.host,
        savedConnection.port,
        savedConnection.username,
        savedConnection.password,
      );
      await connection.init();

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

      final returnedPaths = await connection.getPathsInFolder(
        savedConnection.rootPath,
      );
      final allPaths = returnedPaths.where((path) {
        final fileExtension = p.extension(path).toLowerCase();
        return acceptedFormats.contains(fileExtension);
      }).toList();

      if (allPaths.isEmpty) {
        throw Exception("No valid image files found in the specified path.");
      }
      allPaths.shuffle();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoframeController(
              navigatorKey: widget.navigatorKey,
              connection: connection,
              imagePaths: allPaths,
              duration: Duration(seconds: savedConnection.duration),
              imageCacheSize: savedConnection.imageCacheSize,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorOnSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Connections'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddConnectionDialog(),
          ),
        ],
      ),
      body: _savedConnections.isEmpty
          ? _buildEmptyState()
          : _buildConnectionsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No connections yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to add your first connection',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedConnections.length,
      itemBuilder: (context, index) {
        final connection = _savedConnections[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.computer, size: 32),
            title: Text(connection.name),
            subtitle: Text(
              '${connection.username}@${connection.host}:${connection.port}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteConnection(index),
                ),
                const Icon(Icons.arrow_forward_ios),
              ],
            ),
            onTap: () => _connectToSavedConnection(connection),
          ),
        );
      },
    );
  }

  void _showAddConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.computer),
              title: const Text('SSH Connection'),
              subtitle: const Text('Connect via SSH/SFTP'),
              onTap: () {
                Navigator.pop(context);
                _showSSHConnectionForm();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSSHConnectionForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SSHConnectionForm(
          onConnectionSaved: (connection) {
            _addConnection(connection);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

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
