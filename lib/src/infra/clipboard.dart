import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppFlowyClipboardData {
  const AppFlowyClipboardData({
    this.text,
    this.html,
  });
  final String? text;
  final String? html;
}

class AppFlowyClipboard {
  static AppFlowyClipboardData? _mockData;

  @visibleForTesting
  static String? lastText;

  static Future<void> setData({
    String? text,
    String? html,
  }) async {
    if (text == null) {
      return;
    }

    lastText = text;

    return Clipboard.setData(
      ClipboardData(
        text: text,
      ),
    );
  }

  static Future<AppFlowyClipboardData> getData() async {
    if (_mockData != null) {
      return _mockData!;
    }

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final sanitizedText = data?.text?.replaceAll('\r\n\r\n', '\n').replaceAll('\r\n', '\n');

    return AppFlowyClipboardData(
      text: sanitizedText,
      html: null,
    );
  }

  @visibleForTesting
  static void mockSetData(AppFlowyClipboardData? data) {
    _mockData = data;
  }
}
