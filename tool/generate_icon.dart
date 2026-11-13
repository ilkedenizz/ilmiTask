// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart';

void main() {
  const size = 1024;
  final dir = Directory('assets/icon');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // Design Tokens (Obsidian & International Orange)
  final cCanvas = ColorUint8.rgba(9, 10, 12, 255); // #090A0C
  final cCard = ColorUint8.rgba(18, 20, 24, 255); // #121418
  final cBorder = ColorUint8.rgba(34, 37, 44, 255); // #22252C
  final cBorderHi = ColorUint8.rgba(42, 46, 55, 255); // #2A2E37
  final cAccent = ColorUint8.rgba(255, 85, 0, 255); // #FF5500
  final cAccentGlow = ColorUint8.rgba(255, 120, 40, 255);
  final cWhite = ColorUint8.rgba(243, 244, 246, 255); // #F3F4F6
  final cTransparent = ColorUint8.rgba(0, 0, 0, 0);

  // Helper to draw thick circle outline
  void drawRing(Image img, int cx, int cy, int radius, int thickness, Color color) {
    for (int r = radius - (thickness ~/ 2); r <= radius + (thickness ~/ 2); r++) {
      drawCircle(img, x: cx, y: cy, radius: r, color: color, antialias: true);
    }
  }

  // Helper to draw geometric tick-marks around the ring (Nothing OS aesthetic)
  void drawClockTicks(Image img, int cx, int cy, int r, Color tickColor, Color dotColor) {
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final x1 = (cx + (r - 28) * math.cos(angle)).round();
      final y1 = (cy + (r - 28) * math.sin(angle)).round();
      final x2 = (cx + (r - 10) * math.cos(angle)).round();
      final y2 = (cy + (r - 10) * math.sin(angle)).round();

      if (i % 3 == 0) {
        // Cardinal dots (12, 3, 6, 9)
        final dotX = (cx + (r - 20) * math.cos(angle)).round();
        final dotY = (cy + (r - 20) * math.sin(angle)).round();
        drawCircle(img, x: dotX, y: dotY, radius: 8, color: dotColor, antialias: true);
      } else {
        drawLine(
          img,
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          color: tickColor,
          thickness: 4,
          antialias: true,
        );
      }
    }
  }

  // Helper to draw centerpiece emblem (Ring + Checkmark + Alarm Ring Dot)
  void drawCenterpiece(Image img, {required bool isForegroundOnly}) {
    const cx = 512;
    const cy = 512;
    const ringRadius = 240;

    // 1. Subtle dark circular backdropplate for foreground contrast
    if (isForegroundOnly) {
      drawCircle(img, x: cx, y: cy, radius: ringRadius + 45, color: ColorUint8.rgba(9, 10, 12, 220), antialias: true);
    }

    // 2. Outer hairline architectural ring
    drawRing(img, cx, cy, ringRadius + 30, 4, cBorder);

    // 3. Main geometric alarm dial ring
    drawRing(img, cx, cy, ringRadius, 14, cBorderHi);

    // 4. International Orange active alarm arc (Top arc representing active alarm indicator)
    for (double deg = -60; deg <= 60; deg += 0.5) {
      final rad = deg * math.pi / 180 - math.pi / 2;
      for (int t = -7; t <= 7; t++) {
        final r = ringRadius + t;
        final px = (cx + r * math.cos(rad)).round();
        final py = (cy + r * math.sin(rad)).round();
        if (px >= 0 && px < size && py >= 0 && py < size) {
          img.setPixel(px, py, cAccent);
        }
      }
    }

    // 5. Dial tick marks inside the ring
    drawClockTicks(img, cx, cy, ringRadius, cBorder, cAccent);

    // 6. Glowing Alarm Pip / Signal Dot at 12 o'clock
    const pipX = cx;
    final pipY = cy - ringRadius;
    drawCircle(img, x: pipX, y: pipY, radius: 24, color: cAccentGlow, antialias: true);
    drawCircle(img, x: pipX, y: pipY, radius: 18, color: cAccent, antialias: true);
    drawCircle(img, x: pipX, y: pipY, radius: 8, color: cWhite, antialias: true);

    // 7. Sharp, high-contrast Precision Checkmark in center
    // Checkmark coordinates:
    // Left point: (400, 525)
    // Vertex:     (475, 600)
    // Tip:        (630, 435)
    drawLine(img, x1: 400, y1: 525, x2: 475, y2: 600, color: cWhite, thickness: 38, antialias: true);
    drawLine(img, x1: 475, y1: 600, x2: 630, y2: 435, color: cWhite, thickness: 38, antialias: true);

    // Rounded joints for the checkmark
    drawCircle(img, x: 400, y: 525, radius: 19, color: cWhite, antialias: true);
    drawCircle(img, x: 475, y: 600, radius: 19, color: cWhite, antialias: true);
    drawCircle(img, x: 630, y: 435, radius: 19, color: cWhite, antialias: true);

    // Orange precision focal dot near the vertex
    drawCircle(img, x: 512, y: 685, radius: 7, color: cAccent, antialias: true);
  }

  print('Generating app_icon.png (1024x1024)...');
  final fullIcon = Image(width: size, height: size, numChannels: 4);
  fill(fullIcon, color: cCanvas);

  // Subtle rounded architectural background card
  const pad = 64;
  for (int y = pad; y < size - pad; y++) {
    for (int x = pad; x < size - pad; x++) {
      // Rounded corner math
      const r = 160;
      final inCornerTL = x < pad + r && y < pad + r && math.sqrt(math.pow(x - (pad + r), 2) + math.pow(y - (pad + r), 2)) > r;
      final inCornerTR = x > size - pad - r && y < pad + r && math.sqrt(math.pow(x - (size - pad - r), 2) + math.pow(y - (pad + r), 2)) > r;
      final inCornerBL = x < pad + r && y > size - pad - r && math.sqrt(math.pow(x - (pad + r), 2) + math.pow(y - (size - pad - r), 2)) > r;
      final inCornerBR = x > size - pad - r && y > size - pad - r && math.sqrt(math.pow(x - (size - pad - r), 2) + math.pow(y - (size - pad - r), 2)) > r;

      if (!inCornerTL && !inCornerTR && !inCornerBL && !inCornerBR) {
        // Border edge
        final isBorder = (x - pad < 6 || size - pad - x <= 6 || y - pad < 6 || size - pad - y <= 6);
        fullIcon.setPixel(x, y, isBorder ? cBorder : cCard);
      }
    }
  }

  // Draw centerpiece on full icon
  drawCenterpiece(fullIcon, isForegroundOnly: false);
  File('assets/icon/app_icon.png').writeAsBytesSync(encodePng(fullIcon));
  print('Saved assets/icon/app_icon.png');

  print('Generating app_icon_foreground.png (1024x1024)...');
  final foregroundIcon = Image(width: size, height: size, numChannels: 4);
  fill(foregroundIcon, color: cTransparent);

  // Draw centerpiece on transparent canvas
  drawCenterpiece(foregroundIcon, isForegroundOnly: true);
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(encodePng(foregroundIcon));
  print('Saved assets/icon/app_icon_foreground.png');

  print('All custom icons generated successfully.');
}
