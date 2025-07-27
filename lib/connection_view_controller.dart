import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
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

  bool _obscurePassword;
  bool _saveChecked;

  final _secureStorage = const FlutterSecureStorage();

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
    final context = widget.navigatorKey.currentContext;
    if (context != null && _formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('host', _hostController.text);
      await prefs.setString('port', _portController.text);
      await prefs.setString('username', _usernameController.text);
      await prefs.setString('rootPath', _rootPath.text);
      await prefs.setString('duration', _duration.text);
      await _secureStorage.write(
        key: 'password',
        value: _passwordController.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Inputs saved!')));
      }
    }
  }

  Future<void> _loadSavedInputs() async {
    final prefs = await SharedPreferences.getInstance();
    final password = await _secureStorage.read(key: 'password');
    setState(() {
      _hostController.text = prefs.getString('host') ?? '';
      _portController.text = prefs.getString('port') ?? '';
      _usernameController.text = prefs.getString('username') ?? '';
      _passwordController.text = password ?? '';
      _rootPath.text = prefs.getString('rootPath') ?? '';
      _duration.text = prefs.getString('duration') ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    Checkbox(
                      value: _saveChecked,
                      onChanged: (val) {
                        setState(() {
                          _saveChecked = val ?? false;
                          if (_saveChecked) {
                            _saveInputs();
                          }
                        });
                      },
                    ),
                    const Text('Save'),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _saveInputs,
                      child: const Text('Save Now'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Connect Button
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final port = int.tryParse(_portController.text);
                      final socket = await SSHSocket.connect(
                        _hostController.text,
                        port!,
                      );
                      final client = SSHClient(
                        socket,
                        username: _usernameController.text,
                        onPasswordRequest: () => _passwordController.text,
                      );
                      final sftp = await client.sftp();
                      final loadTargetPathCommand =
                          'cd ${_rootPath.text} && find "\$(pwd)" -type f';
                      final result = await client.run(
                        loadTargetPathCommand,
                        stderr: false,
                      );
                      final allPaths = utf8
                          .decode(result)
                          .split("\n")
                          .where((path) => path.trim().isNotEmpty)
                          .toList();
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
                              duration: Duration(
                                seconds: int.parse(_duration.text),
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Connect', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
