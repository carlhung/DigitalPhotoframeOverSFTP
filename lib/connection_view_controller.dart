import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:photoframe/helpers.dart';
import 'package:photoframe/photoframe_view_controller.dart';
import 'package:photoframe/ssh_connection_form.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:photoframe/connections.dart';
import 'package:photoframe/app_settings.dart';
import 'package:photoframe/settings_page.dart';

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

      final allPaths = await connection.getPathsInFolder(
        savedConnection.rootPath,
      );

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
              duration: Duration(seconds: AppSettings.duration),
              imageCacheSize: AppSettings.imageCacheSize,
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
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(),
          ),
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

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
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
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('Google Drive'),
              subtitle: const Text('Connect to Google Drive'),
              onTap: () {
                Navigator.pop(context);
                _connectToGoogleDrive();
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

  Future<void> _connectToGoogleDrive() async {
    try {
      final connection = GDconnection();
      await connection.init();

      final allPaths = await connection.getPathsInFolder('');

      if (allPaths.isEmpty) {
        throw Exception("No valid image files found in Google Drive.");
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
              duration: Duration(seconds: AppSettings.duration),
              imageCacheSize: AppSettings.imageCacheSize,
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
}
