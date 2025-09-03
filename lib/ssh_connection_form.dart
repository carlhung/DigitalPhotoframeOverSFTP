import 'package:flutter/material.dart';
import 'package:photoframe/connections.dart';

class SSHConnectionForm extends StatefulWidget {
  final Function(SavedConnection) onConnectionSaved;

  const SSHConnectionForm({super.key, required this.onConnectionSaved});

  @override
  State<SSHConnectionForm> createState() => _SSHConnectionFormState();
}

class _SSHConnectionFormState extends State<SSHConnectionForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootPathController = TextEditingController(text: '~/');
  final _durationController = TextEditingController(text: '5');
  final _imageCacheSizeController = TextEditingController(text: '10');

  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootPathController.dispose();
    _durationController.dispose();
    _imageCacheSizeController.dispose();
    super.dispose();
  }

  void _saveConnection() {
    if (_formKey.currentState!.validate()) {
      final connection = SavedConnection(
        name: _nameController.text,
        type: 'SSH',
        host: _hostController.text,
        port: int.parse(_portController.text),
        username: _usernameController.text,
        password: _passwordController.text,
        rootPath: _rootPathController.text,
        duration: int.parse(_durationController.text),
        imageCacheSize: int.parse(_imageCacheSizeController.text),
      );
      widget.onConnectionSaved(connection);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('SSH Connection'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _saveConnection,
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Connection Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Connection Name',
                    hintText: 'My Server',
                    prefixIcon: Icon(Icons.label),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a connection name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

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
                  controller: _rootPathController,
                  decoration: const InputDecoration(
                    labelText: 'Image Root Path',
                    hintText: '~/',
                    prefixIcon: Icon(Icons.folder),
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
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (seconds)',
                    hintText: '5',
                    prefixIcon: Icon(Icons.timer),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a duration';
                    }
                    final num = int.tryParse(value);
                    if (num == null || num < 1) {
                      return 'Please enter a valid duration';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Image Cache Size
                TextFormField(
                  controller: _imageCacheSizeController,
                  decoration: const InputDecoration(
                    labelText: 'Image Cache Size',
                    hintText: '10',
                    prefixIcon: Icon(Icons.storage),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a cache size';
                    }
                    final num = int.tryParse(value);
                    if (num == null || num < 1) {
                      return 'Please enter a valid cache size';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Test Connection Button
                // OutlinedButton(
                //   onPressed: () {
                //     // TODO: Implement test connection
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(
                //         content: Text(
                //           'Test connection functionality coming soon',
                //         ),
                //       ),
                //     );
                //   },
                //   child: const Text('Test Connection'),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
