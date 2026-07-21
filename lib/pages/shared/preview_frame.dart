import 'dart:async';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

// Shared styling + color extraction for the round-screen preview areas.
//
// Every preview shows the badge's circular screen as a circle floating on a
// color field: the area around the circle is filled with a background color
// (Palette-extracted from the *currently framed* media for image/video/
// slideshow, or the manually-chosen color for danmaku), and the circle carries
// a soft drop shadow and a faint white halo — matching the design reference
// (color-transition-preview.html). All of this is preview-only and never
// affects the converted resource.

/// Gap between the floating circle and the edge of the square preview area,
/// leaving room for the drop shadow / halo to show against the color field.
const double kPreviewMargin = 16;

/// Circular preview presentation shared by all pages. [bg] fills the area
/// around the floating circle; the [size]×[size] circle carries a soft drop
/// shadow and a faint white halo hugging its edge.
/// [child] is the circle's content and is clipped to the circle.
Widget previewCircle({
  required double size,
  required Color? bg,
  required Widget child,
}) {
  return Container(
    // Extracted / chosen color fills the field around the floating circle.
    color: bg,
    alignment: Alignment.center,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Soft drop shadow → the circle floats above the color field.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: size * 0.11,
            offset: Offset(0, size * 0.045),
          ),
          // Faint white halo hugging the edge (the reference's ~6px ring).
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.13),
            spreadRadius: size * 0.03,
          ),
        ],
      ),
      child: ClipOval(child: child),
    ),
  );
}

/// Source-pixel rectangle currently framed by the [v]×[v] viewport under [m]
/// (the InteractiveViewer transform), clamped to the image bounds. Mirrors the
/// pages' viewport crop math: the image is contain-fit into the v×v box, then
/// pinch-zoom / pan applies [m]. Returns null when the framed region doesn't
/// overlap the image (fully letterboxed) or the viewport isn't laid out yet.
Rect? framedSourceRect(double v, int srcW, int srcH, Matrix4 m) {
  if (v <= 0 || srcW <= 0 || srcH <= 0) return null;
  final double s0 = min(v / srcW, v / srcH); // contain scale in v×v box
  final double lx = (v - srcW * s0) / 2;
  final double ly = (v - srcH * s0) / 2;
  final double k = m.getMaxScaleOnAxis();
  final double denom = k * s0;
  if (denom <= 0) return null;
  final double mtx = m.storage[12];
  final double mty = m.storage[13];
  // Invert the viewport corners (0,0)-(v,v) back to source pixels.
  final double left = -(k * lx + mtx) / denom;
  final double top = -(k * ly + mty) / denom;
  final double l = left.clamp(0.0, srcW.toDouble());
  final double t = top.clamp(0.0, srcH.toDouble());
  final double r = (left + v / denom).clamp(0.0, srcW.toDouble());
  final double b = (top + v / denom).clamp(0.0, srcH.toDouble());
  if (r - l < 1 || b - t < 1) return null; // degenerate / no overlap with image
  return Rect.fromLTRB(l, t, r, b);
}

/// Extract a background color from [image] to fill the preview area outside the
/// circle, optionally limited to [region] (source-pixel Rect) so it tracks the
/// current framing. Returns null when no usable color is found.
///
/// The expensive pixel quantization always runs on a background isolate via
/// [compute] so it never blocks the UI — the user can pinch / pan freely even
/// right after loading. Only the raw-RGBA readback runs on the main isolate.
/// Preview-only: the result must not feed the conversion color.
Future<Color?> extractPreviewBg(ui.Image image, {Rect? region}) async {
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return null;
    final argb = await compute(
      _quantizePalette,
      _PaletteRequest(
        bytes: bytes,
        width: image.width,
        height: image.height,
        maxColors: 12,
        regionLeft: region?.left,
        regionTop: region?.top,
        regionRight: region?.right,
        regionBottom: region?.bottom,
      ),
    );
    return argb == null ? null : Color(argb);
  } catch (_) {
    return null;
  }
}

// Runs on a background isolate: median-cut quantization over the raw RGBA
// pixels (optionally limited to the framed region) → dominant color as ARGB.
// Uses fromByteData (not fromImage) since a ui.Image can't cross isolates.
Future<int?> _quantizePalette(_PaletteRequest req) async {
  Rect? region;
  if (req.regionLeft != null) {
    region = Rect.fromLTRB(
        req.regionLeft!, req.regionTop!, req.regionRight!, req.regionBottom!);
  }
  final palette = await PaletteGenerator.fromByteData(
    EncodedImage(req.bytes, width: req.width, height: req.height),
    region: region,
    maximumColorCount: req.maxColors,
  );
  return _pickColor(palette)?.toARGB32();
}

// Preferred → fallback color selection, shared by both extraction paths.
Color? _pickColor(PaletteGenerator palette) =>
    palette.dominantColor?.color ??
    palette.vibrantColor?.color ??
    palette.mutedColor?.color ??
    (palette.colors.isNotEmpty ? palette.colors.first : null);

// Immutable, sendable payload for the palette isolate. The region is passed as
// plain doubles (not a Rect) to stay trivially sendable across isolates.
class _PaletteRequest {
  const _PaletteRequest({
    required this.bytes,
    required this.width,
    required this.height,
    required this.maxColors,
    this.regionLeft,
    this.regionTop,
    this.regionRight,
    this.regionBottom,
  });
  final ByteData bytes;
  final int width;
  final int height;
  final int maxColors;
  final double? regionLeft;
  final double? regionTop;
  final double? regionRight;
  final double? regionBottom;
}

/// Coalesces rapid calls into one: [run] (re)starts a timer and fires its
/// action only after [delay] of quiet. Used so the background preview-color
/// extraction runs once the user stops pinching / panning, not on every
/// interaction-end. Call [dispose] from the owning State's dispose.
class Debouncer {
  Debouncer(this.delay);
  final Duration delay;
  Timer? _timer;
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Drop any pending action without scheduling a new one — call this when a
  /// new gesture starts so no extraction fires while the finger is still down.
  void cancel() => _timer?.cancel();

  void dispose() => _timer?.cancel();
}
