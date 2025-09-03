import 'package:flutter/material.dart';
import 'package:photoframe/app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  final _imageCacheSizeController = TextEditingController();
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _durationController.dispose();
    _imageCacheSizeController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() {
    setState(() {
      _durationController.text = AppSettings.duration.toString();
      _imageCacheSizeController.text = AppSettings.imageCacheSize.toString();
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final duration = int.parse(_durationController.text);
      final imageCacheSize = int.parse(_imageCacheSizeController.text);
      
      await AppSettings.updateSettings(
        duration: duration,
        imageCacheSize: imageCacheSize,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _resetToDefaults() async {
    await AppSettings.resetToDefaults();
    _loadCurrentSettings();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings reset to defaults'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.slideshow, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Slideshow Settings',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              TextFormField(
                                controller: _durationController,
                                decoration: const InputDecoration(
                                  labelText: 'Duration (seconds)',
                                  hintText: '5',
                                  prefixIcon: Icon(Icons.timer),
                                  border: OutlineInputBorder(),
                                  helperText: 'How long each image is displayed',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a duration';
                                  }
                                  final num = int.tryParse(value);
                                  if (num == null || num < 1) {
                                    return 'Please enter a valid duration (minimum 1 second)';
                                  }
                                  if (num > 3600) {
                                    return 'Duration cannot exceed 1 hour (3600 seconds)';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.storage, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text(
                                    'Performance Settings',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              TextFormField(
                                controller: _imageCacheSizeController,
                                decoration: const InputDecoration(
                                  labelText: 'Image Cache Size',
                                  hintText: '10',
                                  prefixIcon: Icon(Icons.cached),
                                  border: OutlineInputBorder(),
                                  helperText: 'Number of images to keep in memory',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a cache size';
                                  }
                                  final num = int.tryParse(value);
                                  if (num == null || num < 1) {
                                    return 'Please enter a valid cache size (minimum 1)';
                                  }
                                  if (num > 100) {
                                    return 'Cache size cannot exceed 100 images';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _resetToDefaults,
                        icon: Icon(Icons.refresh),
                        label: Text('Reset to Defaults'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: BorderSide(color: Colors.orange),
                        ),
                      ),
                      SizedBox(height: 16),
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'About These Settings',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                '• Duration: Controls how long each image is displayed during slideshow\n'
                                '• Image Cache Size: Higher values provide smoother transitions but use more memory\n'
                                '• These settings apply to all connection types (SSH, Google Drive, etc.)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}