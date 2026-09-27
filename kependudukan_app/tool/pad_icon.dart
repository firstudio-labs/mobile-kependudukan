import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

// Simple script to add padding and optional background color around an icon.
// Usage: dart tool/pad_icon.dart <inputPath> <outputPath> <padPercent> [bgHex]
// padPercent is the fraction of the final canvas reserved as padding on each side (e.g., 0.12)
// bgHex is optional hex color like #FFFFFF (default transparent)
void main(List<String> args) {
  if (args.length < 3) {
    stderr.writeln(
        'Usage: dart tool/pad_icon.dart <inputPath> <outputPath> <padPercent> [bgHex]');
    exit(64);
  }

  final String inputPath = args[0];
  final String outputPath = args[1];
  final double padPercent = double.tryParse(args[2]) ?? 0.12; // default 12%
  final String? bgHex = args.length >= 4 ? args[3] : null;

  if (!File(inputPath).existsSync()) {
    stderr.writeln('Input file not found: ' + inputPath);
    exit(66);
  }

  final Uint8List bytes = File(inputPath).readAsBytesSync();
  final img.Image? source = img.decodeImage(bytes);
  if (source == null) {
    stderr.writeln('Failed to decode image: ' + inputPath);
    exit(65);
  }

  // Make canvas square based on the longest side
  final int maxSide =
      source.width > source.height ? source.width : source.height;

  // Compute target canvas with padding fraction on each side
  // If padPercent=0.12, content area ~= 76% and margins 12% each side
  final double contentScale = (1.0 - (padPercent * 2)).clamp(0.5, 0.98);
  final int canvasSize = maxSide;
  final int targetContentSize = (canvasSize * contentScale).round();

  // Fit the source into targetContentSize (preserving aspect ratio)
  final img.Image fitted = img.copyResize(
    source,
    width: source.width >= source.height ? targetContentSize : null,
    height: source.height > source.width ? targetContentSize : null,
    interpolation: img.Interpolation.cubic,
  );

  // Create canvas
  final img.Image canvas = img.Image(
    width: canvasSize,
    height: canvasSize,
  );
  // Parse background color if provided, else transparent
  if (bgHex != null && bgHex.isNotEmpty) {
    final _ColorRGBA c = _parseHexColor(bgHex);
    img.fill(canvas, color: img.ColorRgba8(c.r, c.g, c.b, c.a));
  } else {
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  }

  // Center the fitted image on the canvas
  final int dx = ((canvasSize - fitted.width) / 2).round();
  final int dy = ((canvasSize - fitted.height) / 2).round();
  img.compositeImage(canvas, fitted, dstX: dx, dstY: dy);

  // Encode as PNG
  final List<int> outPng = img.encodePng(canvas);
  File(outputPath).createSync(recursive: true);
  File(outputPath).writeAsBytesSync(outPng);
  stdout.writeln('Wrote padded icon to: ' +
      outputPath +
      ' (pad=' +
      padPercent.toString() +
      ', bg=' +
      (bgHex ?? 'transparent') +
      ')');
}

class _ColorRGBA {
  final int r;
  final int g;
  final int b;
  final int a;
  _ColorRGBA(this.r, this.g, this.b, this.a);
}

_ColorRGBA _parseHexColor(String hex) {
  String h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 3) {
    // RGB shorthand like FFF
    h = h.split('').map((c) => c + c).join();
  }
  if (h.length == 6) {
    final int v = int.parse(h, radix: 16);
    return _ColorRGBA((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF, 0xFF);
  }
  if (h.length == 8) {
    // AARRGGBB
    final int v = int.parse(h, radix: 16);
    return _ColorRGBA(
        (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF, (v >> 24) & 0xFF);
  }
  // Fallback to white
  return _ColorRGBA(255, 255, 255, 255);
}
