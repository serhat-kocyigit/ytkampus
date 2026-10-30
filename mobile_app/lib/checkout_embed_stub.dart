import 'package:flutter/widgets.dart';
import 'dart:typed_data';

Widget buildWebCheckout(String html, String baseUrl) => const SizedBox.shrink();

String createWebMediaUrl(Uint8List bytes, String mime) =>
    throw UnsupportedError('Web only');
void revokeWebMediaUrl(String url) {}
void saveWebMediaBytes(Uint8List bytes, String name, String mime) =>
    throw UnsupportedError('Web only');
