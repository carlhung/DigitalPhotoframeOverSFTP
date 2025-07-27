import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:photoframe/helpers.dart';
import 'package:photoframe/photoframe_view_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConnectionFormWidget extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const ConnectionFormWidget({super.key, required this.navigatorKey});

  @override
  State<ConnectionFormWidget> createState() => _ConnectionFormWidgetState();
}

class _ConnectionFormWidgetState extends State<ConnectionFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootPath = TextEditingController();
  final _duration = TextEditingController();

  final _hostKey = "host";
  final _portKey = "port";
  final _usernameKey = "username";
  final _passwordKey = "password";
  final _rootPathKey = "rootPath";
  final _durationKey = "duration";
  final _saveCheckedKey = "saveChecked";

  bool _obscurePassword;
  bool _saveChecked;

  final _secureStorage = const FlutterSecureStorage();

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

  _ConnectionFormWidgetState() : _obscurePassword = true, _saveChecked = false {
    _loadSavedInputs();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootPath.dispose();
    super.dispose();
  }

  Future<void> _saveInputs() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_hostKey, _hostController.text);
      await prefs.setString(_portKey, _portController.text);
      await prefs.setString(_usernameKey, _usernameController.text);
      await prefs.setString(_rootPathKey, _rootPath.text);
      await prefs.setString(_durationKey, _duration.text);
      await prefs.setBool(_saveCheckedKey, _saveChecked);
      await _secureStorage.write(
        key: _passwordKey,
        value: _passwordController.text,
      );
    }
  }

  Future<void> _clearSavedInputs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hostKey);
    await prefs.remove(_portKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_rootPathKey);
    await prefs.remove(_durationKey);
    await prefs.remove(_saveCheckedKey);
    await _secureStorage.delete(key: _passwordKey);
  }

  Future<void> _loadSavedInputs() async {
    final prefs = await SharedPreferences.getInstance();
    final password = await _secureStorage.read(key: _passwordKey) ?? '';
    final host = prefs.getString(_hostKey) ?? '';
    final port = prefs.getString(_portKey) ?? '';
    final username = prefs.getString(_usernameKey) ?? '';
    final rootPath = prefs.getString(_rootPathKey) ?? '';
    final duration = prefs.getString(_durationKey) ?? '';
    final saveChecked = prefs.getBool(_saveCheckedKey) ?? false;

    if (host.isNotEmpty &&
        password.isNotEmpty &&
        username.isNotEmpty &&
        port.isNotEmpty &&
        rootPath.isNotEmpty &&
        duration.isNotEmpty) {
      setState(() {
        _hostController.text = host;
        _portController.text = port;
        _usernameController.text = username;
        _passwordController.text = password;
        _rootPath.text = rootPath;
        _duration.text = duration;
        _saveChecked = saveChecked;
      });

      // Wait for the next frame to ensure the context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _submit(context);
        }
      });
    } else {
      await _clearSavedInputs();
    }
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final port = int.tryParse(_portController.text);
      final socket = await SSHSocket.connect(_hostController.text, port!);
      final client = SSHClient(
        socket,
        username: _usernameController.text,
        onPasswordRequest: () => _passwordController.text,
      );
      final sftp = await client.sftp();
      final loadTargetPathCommand =
          'cd ${_rootPath.text} && find "\$(pwd)" -type f';
      final result = await client.run(loadTargetPathCommand, stderr: false);
      final allPaths = utf8.decode(result).split("\n").where((path) {
        final trimmedPath = path.trim();
        if (trimmedPath.isEmpty) return false;
        final fileExtenion = p.extension(trimmedPath).toLowerCase();
        if (!acceptedFormats.contains(fileExtenion)) return false;
        return true;
      }).toList();
      if (allPaths.isEmpty) {
        throw Exception("No valid image files found in the specified path.");
      }
      allPaths.shuffle();
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoframeController(
              navigatorKey: widget.navigatorKey,
              client: client,
              sftp: sftp,
              imagePaths: allPaths,
              duration: Duration(seconds: int.parse(_duration.text)),
            ),
          ),
        );
        if (_saveChecked) {
          await _saveInputs();
        } else {
          await _clearSavedInputs();
        }
      }
    } catch (e) {
      final context = widget.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        showErrorOnSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Server Connection',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Host Field
                    TextFormField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host',
                        hintText: 'example.com',
                        prefixIcon: Icon(Icons.public),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a host';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Port Field
                    TextFormField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '22',
                        prefixIcon: Icon(Icons.settings_ethernet),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a port';
                        }
                        final port = int.tryParse(value);
                        if (port == null || port < 1 || port > 65535) {
                          return 'Please enter a valid port (1-65535)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'Enter username',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter password',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Image Root Path
                    TextFormField(
                      controller: _rootPath,
                      decoration: const InputDecoration(
                        labelText: 'Image Root Path',
                        hintText: '~/',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a path';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Duration Field
                    TextFormField(
                      controller: _duration,
                      decoration: const InputDecoration(
                        labelText: 'Duration (seconds)',
                        hintText: 'a number of seconds',
                        prefixIcon: Icon(Icons.settings_ethernet),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a number';
                        }
                        final num = int.tryParse(value);
                        if (num == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Save Checkbox and Button
                    Row(
                      children: [
                        const Text('Save: '),
                        Checkbox(
                          value: _saveChecked,
                          onChanged: (val) {
                            setState(() {
                              _saveChecked = val ?? false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Connect Button
                    ElevatedButton(
                      onPressed: () async {
                        await _submit(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Connect',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
