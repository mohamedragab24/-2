import 'dart:async';
import 'package:flutter/services.dart';

class ScreenProtectionService {
  static const MethodChannel _channel =
      MethodChannel('masar_app/screen_protection');

  final StreamController<bool> _blockContentController =
      StreamController<bool>.broadcast();

  Stream<bool> get shouldBlockContent => _blockContentController.stream;

  Future<void> init() async {
    try {
      await _channel.invokeMethod('enable');
      _blockContentController.add(false);
    } catch (_) {
      _blockContentController.add(false);
    }
  }

  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {}

    await _blockContentController.close();
  }

  Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
      _blockContentController.add(false);
    } catch (_) {}
  }

  Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
      _blockContentController.add(false);
    } catch (_) {}
  }
}
