import 'package:flutter/material.dart';

void showErrorOnSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 5),
      content: Text(error.toString()),
    ),
  );
}
