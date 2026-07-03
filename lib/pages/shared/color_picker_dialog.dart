import 'package:flutter/material.dart';

/// Shows a modal HSV color palette. Returns the chosen opaque ARGB int
/// (`0xFFrrggbb`) or `null` if the user cancels.
///
/// Alpha is always forced to `0xFF`: the device renders every pixel as fully
/// opaque RGB565, so a transparent pick would be meaningless.
Future<int?> showColorPickerDialog(BuildContext context, int initialArgb) {
  return showDialog<int>(
    context: context,
    builder: (_) => _ColorPickerDialog(initialArgb: initialArgb),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final int initialArgb;
  const _ColorPickerDialog({required this.initialArgb});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  static const double _svHeight = 180;
  static const List<Color> _hueStops = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(Color(0xFF000000 | (widget.initialArgb & 0xFFFFFF)));
  }

  // HSV → opaque ARGB int, computed directly (avoids version-sensitive Color
  // int accessors) so the returned value matches what the device consumes.
  int get _argb {
    final double h = _hsv.hue, s = _hsv.saturation, v = _hsv.value;
    final double hh = (h % 360) / 60;
    final int i = hh.floor();
    final double f = hh - i;
    final double p = v * (1 - s);
    final double q = v * (1 - s * f);
    final double t = v * (1 - s * (1 - f));
    double r, g, b;
    switch (i % 6) {
      case 0:
        r = v; g = t; b = p; break;
      case 1:
        r = q; g = v; b = p; break;
      case 2:
        r = p; g = v; b = t; break;
      case 3:
        r = p; g = q; b = v; break;
      case 4:
        r = t; g = p; b = v; break;
      default:
        r = v; g = p; b = q; break;
    }
    int ch(double x) => (x * 255).round().clamp(0, 255);
    return 0xFF000000 | (ch(r) << 16) | (ch(g) << 8) | ch(b);
  }

  void _updateSV(Offset pos, double w) {
    final s = (pos.dx / w).clamp(0.0, 1.0);
    final v = (1 - pos.dy / _svHeight).clamp(0.0, 1.0);
    setState(() => _hsv = _hsv.withSaturation(s).withValue(v));
  }

  void _updateHue(double dx, double w) {
    final h = (dx / w).clamp(0.0, 1.0) * 360.0;
    setState(() => _hsv = _hsv.withHue(h));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final int argb = _argb;
    final String hex =
        '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    return AlertDialog(
      title: const Text('调色板', textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSvSquare(),
            const SizedBox(height: 16),
            _buildHueSlider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(argb),
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Text(hex, style: theme.textTheme.titleMedium),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, argb),
          child: const Text('确定'),
        ),
      ],
    );
  }

  // Saturation (x) × value (y) square over the current hue.
  Widget _buildSvSquare() {
    final Color hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: _svHeight,
        child: LayoutBuilder(
          builder: (context, c) {
            final double w = c.maxWidth;
            return GestureDetector(
              onPanDown: (d) => _updateSV(d.localPosition, w),
              onPanUpdate: (d) => _updateSV(d.localPosition, w),
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: hueColor)),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (_hsv.saturation * w - 9).clamp(0.0, w - 18),
                    top: ((1 - _hsv.value) * _svHeight - 9)
                        .clamp(0.0, _svHeight - 18),
                    child: _ringThumb(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHueSlider() {
    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, c) {
          final double w = c.maxWidth;
          return GestureDetector(
            onPanDown: (d) => _updateHue(d.localPosition.dx, w),
            onPanUpdate: (d) => _updateHue(d.localPosition.dx, w),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      gradient: LinearGradient(colors: _hueStops),
                    ),
                  ),
                ),
                Positioned(
                  left: ((_hsv.hue / 360) * w - 3).clamp(0.0, w - 6),
                  top: -2,
                  bottom: -2,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.black26),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ringThumb() {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2)],
      ),
    );
  }
}
