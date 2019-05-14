/*
 * QR.Flutter
 * Copyright (c) 2019 the QR.Flutter authors.
 * See LICENSE for distribution and usage details.
 */
import 'dart:async';
import 'dart:math' as math show pi;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

typedef QrError = void Function(dynamic error);

class QrPainter extends CustomPainter {
  QrPainter({
    @required String data,
    @required this.version,
    this.errorCorrectionLevel = QrErrorCorrectLevel.L,
    this.color = const Color(0xff000000),
    this.emptyColor,
    this.onError,
    this.gapless = false,
  }) : _qr = QrCode(version, errorCorrectionLevel) {
    _init(data);
  }

  QrPainter.fromData({
    @required String data,
    this.errorCorrectionLevel = QrErrorCorrectLevel.L,
    this.color = const Color(0xff000000),
    this.emptyColor,
    this.onError,
    this.gapless = false,
  }) : _qr = QrCode.fromData(
            data: data, errorCorrectLevel: errorCorrectionLevel) {
    _init(data);
  }

  int version = -1; // the qr code version
  final int errorCorrectionLevel; // the qr code error correction level
  final Color color; // the color of the dark squares
  final Color emptyColor; // the other color
  final QrError onError;
  final bool gapless;

  final QrCode _qr; // our qr code data
  final Paint _paint = Paint()..style = PaintingStyle.fill;
  final Paint _paintOutline = Paint()..style = PaintingStyle.stroke;
  bool _hasError = false;

  void _init(String data) {
    _paint.color = color;
    _paintOutline.color = color;
    // configure and make the QR code data
    try {
      _qr.addData(data);
      _qr.make();
    } catch (ex) {
      if (onError != null) {
        _hasError = true;
        this.onError(ex);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_hasError) {
      return;
    }
    if (size.shortestSide == 0) {
      print(
          "[QR] WARN: width or height is zero. You should set a 'size' value or nest this painter in a Widget that defines a non-zero size");
    }

    if (emptyColor != null) {
      canvas.drawColor(emptyColor, BlendMode.color);
    }

    final double moduleSize =
        (size.shortestSide / _qr.moduleCount.toDouble()) + (gapless ? 1 : 0);
    final double radius = moduleSize / 3.0;

    _paintOutline.strokeWidth = moduleSize;

    for (int x = 0; x < _qr.moduleCount; x++) {
      for (int y = 0; y < _qr.moduleCount; y++) {
        if (_QrUtility.isFinderPattern(x, y, _qr.moduleCount)) {
          continue;
        } else if (_qr.isDark(y, x)) {
          final Offset position = Offset(x * moduleSize, y * moduleSize);
          canvas.drawCircle(position, radius, _paint);
        }
      }
    }

    _paintFinderPatterns(canvas, moduleSize);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is QrPainter) {
      return color != oldDelegate.color ||
          errorCorrectionLevel != oldDelegate.errorCorrectionLevel ||
          version != oldDelegate.version ||
          _qr != oldDelegate._qr;
    }
    return false;
  }

  ui.Picture toPicture(double size) {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    paint(canvas, Size(size, size));
    return recorder.endRecording();
  }

  Future<ByteData> toImageData(double size,
      {ui.ImageByteFormat format = ui.ImageByteFormat.png}) async {
    final ui.Image uiImage =
        await toPicture(size).toImage(size.toInt(), size.toInt());
    return await uiImage.toByteData(format: format);
  }

  void _paintFinderPatterns(Canvas canvas, double moduleSize) {
    final double innerOffset = 1.5 * moduleSize;
    const int diameter = _QrUtility._FINDER_SIZE - 1;
    const double innerDiameter = diameter / 2.0;

    final Rect tlPattern = Rect.fromLTWH(0, 0, diameter * moduleSize, diameter * moduleSize);
    final Rect tlPatternInner =
        Rect.fromLTWH(innerOffset, innerOffset, innerDiameter * moduleSize, innerDiameter * moduleSize);
    _drawFinderPattern(canvas, tlPattern, tlPatternInner);

    final Rect trPattern = Rect.fromLTWH(
        (_qr.moduleCount - diameter - 1) * moduleSize, 0, diameter * moduleSize, diameter * moduleSize);
    final Rect trPatternInner = Rect.fromLTWH(trPattern.left + innerOffset,
        innerOffset, innerDiameter * moduleSize, innerDiameter * moduleSize);
    _drawFinderPattern(canvas, trPattern, trPatternInner);

    final Rect blPattern = Rect.fromLTWH(
        0, (_qr.moduleCount - diameter - 1) * moduleSize, diameter * moduleSize, diameter * moduleSize);
    final Rect blPatternInner = Rect.fromLTWH(innerOffset,
        blPattern.top + innerOffset, innerDiameter * moduleSize, innerDiameter * moduleSize);
    _drawFinderPattern(canvas, blPattern, blPatternInner);
  }

  void _drawFinderPattern(Canvas canvas, Rect rect, Rect rectInner) {
    canvas.drawArc(rect, 0, 2 * math.pi, false, _paintOutline);
    canvas.drawArc(rectInner, 0, 2 * math.pi, true, _paint);
  }
}

class _QrUtility {
  static const int _FINDER_SIZE = 7;

  static bool isFinderPattern(int x, int y, int qrSize) =>
      _isTopLeftFinderPattern(x, y) ||
      _isTopRightFinderPattern(x, y, qrSize) ||
      _isBottomLeftFinderPattern(x, y, qrSize);

  static bool _isTopLeftFinderPattern(int x, int y) =>
      x < _FINDER_SIZE && y < _FINDER_SIZE;

  static bool _isTopRightFinderPattern(int x, int y, int qrSize) =>
      x > qrSize - _FINDER_SIZE - 1 && y < _FINDER_SIZE;

  static bool _isBottomLeftFinderPattern(int x, int y, int qrSize) =>
      x < _FINDER_SIZE && y > qrSize - _FINDER_SIZE - 1;
}
