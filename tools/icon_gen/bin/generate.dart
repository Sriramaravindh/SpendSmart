import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  // Generate the master icon at 1024x1024
  final master = generateIcon(1024);

  // Save master for web favicon and iOS
  final masterPath = '../../assets/app_icon.png';
  File(masterPath).createSync(recursive: true);
  File(masterPath).writeAsBytesSync(img.encodePng(master));
  print('Saved master icon: $masterPath');

  // Generate Android mipmap sizes
  for (final entry in sizes.entries) {
    final resized = img.copyResize(master, width: entry.value, height: entry.value, interpolation: img.Interpolation.average);
    final dir = '../../android/app/src/main/res/${entry.key}';
    Directory(dir).createSync(recursive: true);
    File('$dir/ic_launcher.png').writeAsBytesSync(img.encodePng(resized));
    print('Saved ${entry.key}: ${entry.value}x${entry.value}');
  }

  // Web icons
  final web192 = img.copyResize(master, width: 192, height: 192, interpolation: img.Interpolation.average);
  File('../../web/icons/Icon-192.png').writeAsBytesSync(img.encodePng(web192));
  final web512 = img.copyResize(master, width: 512, height: 512, interpolation: img.Interpolation.average);
  File('../../web/icons/Icon-512.png').writeAsBytesSync(img.encodePng(web512));
  final webMask = img.copyResize(master, width: 512, height: 512, interpolation: img.Interpolation.average);
  File('../../web/icons/Icon-maskable-192.png').writeAsBytesSync(img.encodePng(web192));
  File('../../web/icons/Icon-maskable-512.png').writeAsBytesSync(img.encodePng(webMask));
  final favicon = img.copyResize(master, width: 16, height: 16, interpolation: img.Interpolation.average);
  File('../../web/favicon.png').writeAsBytesSync(img.encodePng(favicon));
  print('Saved web icons');

  print('Done! All icons generated.');
}

img.Image generateIcon(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  final cx = size / 2;
  final cy = size / 2;
  final radius = size * 0.5;

  // Colors
  const bg1R = 0x1B, bg1G = 0x1B, bg1B = 0x2F; // dark bg top
  const bg2R = 0x0F, bg2G = 0x0F, bg2B = 0x1A; // darker bg bottom
  const p1R = 0x8B, p1G = 0x5C, p1B = 0xF6; // primary purple
  const p2R = 0xC4, p2G = 0xB5, p2B = 0xFD; // light purple
  const coinR = 0x8B, coinG = 0x5C, coinB = 0xF6; // coin purple
  const coinLR = 0xC4, coinLG = 0xB5, coinLB = 0xFD; // coin light
  const glowR = 0xA7, glowG = 0x8B, glowB = 0xFA; // glow purple
  const sparkR = 0xFF, sparkG = 0xD7, sparkB = 0x00; // gold spark

  // Draw background with rounded square
  final cornerRadius = size * 0.22;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      // Check if inside rounded rect
      if (!_inRoundedRect(x.toDouble(), y.toDouble(), 0, 0, size.toDouble(), size.toDouble(), cornerRadius)) {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }

      // Background gradient (top to bottom)
      final t = y / size;
      final bgR = _lerp(bg1R, bg2R, t);
      final bgG = _lerp(bg1G, bg2G, t);
      final bgB = _lerp(bg1B, bg2B, t);

      // Coin circle
      final coinCx = cx;
      final coinCy = cy + size * 0.02;
      final coinRadius = size * 0.34;
      final dist = sqrt(pow(x - coinCx, 2) + pow(y - coinCy, 2));

      if (dist < coinRadius) {
        // Inside coin — purple gradient with 3D effect
        final coinT = (y - (coinCy - coinRadius)) / (coinRadius * 2);
        final angleFromCenter = atan2(y - coinCy, x - coinCx);
        final normalizedDist = dist / coinRadius;

        // 3D shading: lighter top-left, darker bottom-right
        final shadeAngle = angleFromCenter + pi * 0.75;
        final shade = 0.7 + 0.3 * cos(shadeAngle) * (1 - normalizedDist * 0.3);

        // Gradient from purple to light purple
        int cR = _lerp(coinR, coinLR, coinT * 0.6);
        int cG = _lerp(coinG, coinLG, coinT * 0.6);
        int cB = _lerp(coinB, coinLB, coinT * 0.3);

        cR = (cR * shade).clamp(0, 255).toInt();
        cG = (cG * shade).clamp(0, 255).toInt();
        cB = (cB * shade).clamp(0, 255).toInt();

        // Rim highlight
        if (dist > coinRadius * 0.88 && dist < coinRadius * 0.96) {
          final rimT = ((dist - coinRadius * 0.88) / (coinRadius * 0.08));
          final rimShade = sin(rimT * pi);
          cR = _lerp(cR, coinLR, rimShade * 0.5);
          cG = _lerp(cG, coinLG, rimShade * 0.5);
          cB = _lerp(cB, coinLB, rimShade * 0.5);
        }

        // Inner circle border
        if (dist > coinRadius * 0.78 && dist < coinRadius * 0.82) {
          cR = _lerp(cR, coinLR, 0.3);
          cG = _lerp(cG, coinLG, 0.3);
          cB = _lerp(cB, coinLB, 0.3);
        }

        image.setPixelRgba(x, y, cR, cG, cB, 255);
      } else if (dist < coinRadius + size * 0.03) {
        // Glow around coin
        final glowT = (dist - coinRadius) / (size * 0.03);
        final alpha = ((1 - glowT) * 80).clamp(0, 255).toInt();
        final fR = _lerpDouble(glowR, bgR, glowT);
        final fG = _lerpDouble(glowG, bgG, glowT);
        final fB = _lerpDouble(glowB, bgB, glowT);
        image.setPixelRgba(x, y, fR.toInt(), fG.toInt(), fB.toInt(), 255);
      } else {
        image.setPixelRgba(x, y, bgR, bgG, bgB, 255);
      }
    }
  }

  // Draw ₹ symbol in the coin center
  _drawRupeeSymbol(image, cx, cy + size * 0.02, size * 0.18);

  // Draw sparkle/brain-spark at top-right of coin
  _drawSparkle(image, cx + size * 0.20, cy - size * 0.22, size * 0.08);
  _drawSparkle(image, cx + size * 0.28, cy - size * 0.15, size * 0.05);
  _drawSparkle(image, cx - size * 0.25, cy - size * 0.25, size * 0.04);

  // Draw lightbulb indicator at top-right
  _drawLightbulb(image, (cx + size * 0.24).toInt(), (cy - size * 0.26).toInt(), (size * 0.12).toInt());

  return image;
}

void _drawRupeeSymbol(img.Image image, double cx, double cy, double symbolSize) {
  final s = symbolSize;
  const r = 255, g = 255, b = 255;

  // ₹ drawn with thick lines
  final thickness = (s * 0.12).toInt().clamp(2, 50);

  // Top horizontal line
  _drawThickLine(image, (cx - s * 0.45).toInt(), (cy - s * 0.6).toInt(), (cx + s * 0.45).toInt(), (cy - s * 0.6).toInt(), thickness, r, g, b);

  // Second horizontal line
  _drawThickLine(image, (cx - s * 0.45).toInt(), (cy - s * 0.2).toInt(), (cx + s * 0.45).toInt(), (cy - s * 0.2).toInt(), thickness, r, g, b);

  // Vertical stroke from top
  _drawThickLine(image, (cx - s * 0.3).toInt(), (cy - s * 0.6).toInt(), (cx - s * 0.3).toInt(), (cy - s * 0.2).toInt(), thickness, r, g, b);

  // Curve: top to middle right
  for (double t = 0; t <= 1.0; t += 0.002) {
    final angle = -pi / 2 + t * pi;
    final curveR = s * 0.4;
    final px = cx + cos(angle) * curveR * 0.5;
    final py = (cy - s * 0.4) + sin(angle) * curveR * 0.5 + s * 0.0;
    _drawDot(image, px.toInt(), py.toInt(), thickness ~/ 2, r, g, b);
  }

  // Diagonal leg from middle to bottom-right
  _drawThickLine(image, (cx - s * 0.1).toInt(), (cy - s * 0.2).toInt(), (cx + s * 0.3).toInt(), (cy + s * 0.7).toInt(), thickness, r, g, b);
}

void _drawLightbulb(img.Image image, int cx, int cy, int bulbSize) {
  const gR = 0xFF, gG = 0xD7, gB = 0x00; // gold
  const wR = 0xFF, wG = 0xFF, wB = 0xFF; // white

  // Bulb glow
  for (int y = cy - bulbSize; y <= cy + bulbSize; y++) {
    for (int x = cx - bulbSize; x <= cx + bulbSize; x++) {
      if (x < 0 || x >= image.width || y < 0 || y >= image.height) continue;
      final dist = sqrt(pow(x - cx, 2) + pow(y - cy, 2));
      if (dist < bulbSize * 0.6) {
        // Bright center
        final t = dist / (bulbSize * 0.6);
        final r = _lerpDouble(wR, gR, t * 0.5).toInt();
        final g = _lerpDouble(wG, gG, t * 0.5).toInt();
        final b = _lerpDouble(wB, gB, t * 0.8).toInt();
        image.setPixelRgba(x, y, r, g, b, 255);
      } else if (dist < bulbSize) {
        // Outer glow
        final t = (dist - bulbSize * 0.6) / (bulbSize * 0.4);
        final alpha = ((1 - t) * 150).clamp(0, 255).toInt();
        final pixel = image.getPixel(x, y);
        final pr = pixel.r.toInt();
        final pg = pixel.g.toInt();
        final pb = pixel.b.toInt();
        final blend = alpha / 255.0;
        final r = _lerpDouble(pr, gR, blend).toInt();
        final g = _lerpDouble(pg, gG, blend).toInt();
        final b = _lerpDouble(pb, gB, blend).toInt();
        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  // Bulb base (small rectangle)
  final baseW = (bulbSize * 0.35).toInt();
  final baseH = (bulbSize * 0.25).toInt();
  for (int y = cy + (bulbSize * 0.4).toInt(); y < cy + (bulbSize * 0.4).toInt() + baseH; y++) {
    for (int x = cx - baseW; x <= cx + baseW; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        image.setPixelRgba(x, y, gR, gG ~/ 2, 0, 200);
      }
    }
  }

  // Rays
  for (int i = 0; i < 6; i++) {
    final angle = i * pi / 3 - pi / 6;
    final startR = bulbSize * 0.65;
    final endR = bulbSize * 1.1;
    final sx = cx + (cos(angle) * startR).toInt();
    final sy = cy + (sin(angle) * startR).toInt();
    final ex = cx + (cos(angle) * endR).toInt();
    final ey = cy + (sin(angle) * endR).toInt();
    _drawThickLine(image, sx, sy, ex, ey, max(1, bulbSize ~/ 10), gR, gG, 0x40);
  }
}

void _drawSparkle(img.Image image, double cx, double cy, double sparkSize) {
  const r = 0xFF, g = 0xFF, b = 0xFF;
  final thick = max(1, (sparkSize * 0.2).toInt());

  // 4-pointed star
  _drawThickLine(image, cx.toInt(), (cy - sparkSize).toInt(), cx.toInt(), (cy + sparkSize).toInt(), thick, r, g, b);
  _drawThickLine(image, (cx - sparkSize).toInt(), cy.toInt(), (cx + sparkSize).toInt(), cy.toInt(), thick, r, g, b);

  // Diagonal points (smaller)
  final ds = sparkSize * 0.6;
  _drawThickLine(image, (cx - ds).toInt(), (cy - ds).toInt(), (cx + ds).toInt(), (cy + ds).toInt(), max(1, thick - 1), r, g, b);
  _drawThickLine(image, (cx + ds).toInt(), (cy - ds).toInt(), (cx - ds).toInt(), (cy + ds).toInt(), max(1, thick - 1), r, g, b);
}

void _drawThickLine(img.Image image, int x0, int y0, int x1, int y1, int thickness, int r, int g, int b) {
  final dx = x1 - x0;
  final dy = y1 - y0;
  final steps = max(dx.abs(), dy.abs());
  if (steps == 0) {
    _drawDot(image, x0, y0, thickness, r, g, b);
    return;
  }

  for (int i = 0; i <= steps; i++) {
    final t = i / steps;
    final x = (x0 + dx * t).round();
    final y = (y0 + dy * t).round();
    _drawDot(image, x, y, thickness, r, g, b);
  }
}

void _drawDot(img.Image image, int cx, int cy, int radius, int r, int g, int b) {
  for (int dy = -radius; dy <= radius; dy++) {
    for (int dx = -radius; dx <= radius; dx++) {
      if (dx * dx + dy * dy <= radius * radius) {
        final px = cx + dx;
        final py = cy + dy;
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          image.setPixelRgba(px, py, r, g, b, 255);
        }
      }
    }
  }
}

bool _inRoundedRect(double x, double y, double rx, double ry, double rw, double rh, double r) {
  if (x < rx + r && y < ry + r) {
    return pow(x - (rx + r), 2) + pow(y - (ry + r), 2) <= r * r;
  }
  if (x > rx + rw - r && y < ry + r) {
    return pow(x - (rx + rw - r), 2) + pow(y - (ry + r), 2) <= r * r;
  }
  if (x < rx + r && y > ry + rh - r) {
    return pow(x - (rx + r), 2) + pow(y - (ry + rh - r), 2) <= r * r;
  }
  if (x > rx + rw - r && y > ry + rh - r) {
    return pow(x - (rx + rw - r), 2) + pow(y - (ry + rh - r), 2) <= r * r;
  }
  return x >= rx && x < rx + rw && y >= ry && y < ry + rh;
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);
double _lerpDouble(num a, num b, double t) => a + (b - a) * t;
