import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/encoder.dart';
import '../../../services/stream_transport.dart';

// Dark, iPhone-camera-style palette to match the capture page.
const Color _kSheetBg = Color(0xFF1C1C1E);
const Color _kFieldBg = Color(0xFF2C2C2E);
const Color _kAccent = Color(0xFFFFCC00); // iOS yellow

/// Bottom-sheet parameter menu for the encoding test bench.
///
/// Returns the edited [EncoderConfig] via `Navigator.pop`, or null if dismissed
/// without applying. Resolution and frame rate are free-form numeric inputs.
class EncoderSettingsSheet extends StatefulWidget {
  final EncoderConfig initial;

  const EncoderSettingsSheet({super.key, required this.initial});

  /// Convenience launcher.
  static Future<EncoderConfig?> show(
    BuildContext context,
    EncoderConfig initial,
  ) {
    return showModalBottomSheet<EncoderConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EncoderSettingsSheet(initial: initial),
    );
  }

  @override
  State<EncoderSettingsSheet> createState() => _EncoderSettingsSheetState();
}

class _EncoderSettingsSheetState extends State<EncoderSettingsSheet> {
  late EncoderConfig _cfg;
  late final TextEditingController _widthCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _fpsCtrl;

  @override
  void initState() {
    super.initState();
    _cfg = widget.initial;
    _widthCtrl = TextEditingController(text: '${_cfg.width}');
    _heightCtrl = TextEditingController(text: '${_cfg.height}');
    _fpsCtrl = TextEditingController(text: '${_cfg.fps}');
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _fpsCtrl.dispose();
    super.dispose();
  }

  /// Parse the text fields into the config and pop with the result.
  void _apply() {
    final w = int.tryParse(_widthCtrl.text.trim()) ?? _cfg.width;
    final h = int.tryParse(_heightCtrl.text.trim()) ?? _cfg.height;
    final fps = int.tryParse(_fpsCtrl.text.trim()) ?? _cfg.fps;

    // Encoders require even dimensions; clamp to sane bounds.
    final cfg = _cfg.copyWith(
      width: (w.clamp(16, 4096) ~/ 2) * 2,
      height: (h.clamp(16, 4096) ~/ 2) * 2,
      fps: fps.clamp(1, 120),
    );
    Navigator.of(context).pop(cfg);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrollable body — the action buttons below stay pinned.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grab handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      '编码参数',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Streaming transport ──
                    _label('传输方式'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: StreamTransportKind.values.map((k) {
                        return _choice(
                          label: k.label,
                          selected: _cfg.transport == k,
                          onTap: () => setState(() {
                            _cfg = _cfg.copyWith(transport: k);
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ── Format ──
                    _label('编码格式'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: EncoderFormat.values.map((f) {
                        return _choice(
                          label: f.label,
                          selected: _cfg.format == f,
                          onTap: () =>
                              setState(() => _cfg = _cfg.copyWith(format: f)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ── Resolution (scale target) ──
                    _label('输出分辨率'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _numField(_widthCtrl, '宽')),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('×',
                              style: TextStyle(color: Colors.white70)),
                        ),
                        Expanded(child: _numField(_heightCtrl, '高')),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '等比例：先按输出比例裁剪，再缩放到该分辨率',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 20),

                    // ── Crop / digital zoom ──
                    _sliderRow(
                      title: '画面裁剪（中心缩放）',
                      value: '${_cfg.cropZoom.toStringAsFixed(1)}×',
                    ),
                    _slider(
                      value: _cfg.cropZoom,
                      min: 1.0,
                      max: 4.0,
                      divisions: 30,
                      onChanged: (v) => setState(() {
                        _cfg = _cfg.copyWith(cropZoom: (v * 10).round() / 10);
                      }),
                    ),
                    const SizedBox(height: 8),

                    // ── Frame rate ──
                    _label('帧率 (fps)'),
                    const SizedBox(height: 8),
                    SizedBox(width: 140, child: _numField(_fpsCtrl, 'fps')),
                    const SizedBox(height: 20),

                    // ── H.264: bitrate + I-frame interval ──
                    if (_cfg.format == EncoderFormat.h264) ...[
                      _sliderRow(
                        title: '编码质量（码率）',
                        value: _formatBitrate(_cfg.bitrate),
                      ),
                      _slider(
                        // 50 kbps … 4 Mbps in 50-kbps steps. The low end is for BLE
                        // streaming (frames must fit the credit window).
                        value: (_cfg.bitrate / 1000).clamp(50, 4000).toDouble(),
                        min: 50,
                        max: 4000,
                        divisions: 79,
                        onChanged: (v) => setState(() {
                          _cfg = _cfg.copyWith(bitrate: v.round() * 1000);
                        }),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '蓝牙投屏建议 ≤ 300 kbps,并配合低分辨率/帧率减小每帧体积',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      _sliderRow(
                          title: 'I 帧间隔', value: '${_cfg.iFrameIntervalSec} s'),
                      _slider(
                        value: _cfg.iFrameIntervalSec.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: (v) => setState(() {
                          _cfg = _cfg.copyWith(iFrameIntervalSec: v.round());
                        }),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── MSV1: inter-frame skip (P-frames) + threshold ──
                    if (_cfg.format == EncoderFormat.mvs1) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '帧间跳过（P 帧）',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch(
                            value: _cfg.msv1Skip,
                            activeThumbColor: _kAccent,
                            onChanged: (v) => setState(
                                () => _cfg = _cfg.copyWith(msv1Skip: v)),
                          ),
                        ],
                      ),
                      if (_cfg.msv1Skip) ...[
                        _sliderRow(
                          title: '跳过阈值',
                          value: '${_cfg.msv1SkipThr}',
                        ),
                        _slider(
                          value: _cfg.msv1SkipThr.toDouble(),
                          min: 0,
                          max: 15,
                          divisions: 15,
                          onChanged: (v) => setState(() =>
                              _cfg = _cfg.copyWith(msv1SkipThr: v.round())),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _sliderRow(
                          title: '关键帧间隔', value: '${_cfg.iFrameIntervalSec} s'),
                      _slider(
                        value: _cfg.iFrameIntervalSec.toDouble(),
                        min: 1,
                        max: 10,
                        divisions: 9,
                        onChanged: (v) => setState(() {
                          _cfg = _cfg.copyWith(iFrameIntervalSec: v.round());
                        }),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '投屏丢包时，色块最多持续到下一个关键帧',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── JPEG: quality ──
                    if (_cfg.format == EncoderFormat.jpeg) ...[
                      _sliderRow(
                          title: 'JPEG 质量', value: '${_cfg.jpegQuality}'),
                      _slider(
                        value: _cfg.jpegQuality.toDouble(),
                        min: 1,
                        max: 100,
                        divisions: 99,
                        onChanged: (v) => setState(
                            () => _cfg = _cfg.copyWith(jpegQuality: v.round())),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── Record to file (alongside streaming) ──
                    const Divider(color: Colors.white12, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '录制到文件',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '投屏的同时把编码流保存到本地',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _cfg.recordToFile,
                          activeThumbColor: _kAccent,
                          onChanged: (v) => setState(
                              () => _cfg = _cfg.copyWith(recordToFile: v)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ── Pinned action buttons (do not scroll with the body) ──
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '应用',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBitrate(int bps) {
    if (bps < 1000000) return '${(bps / 1000).round()} kbps';
    return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      backgroundColor: _kFieldBg,
      selectedColor: _kAccent,
      side: BorderSide.none,
      labelStyle: TextStyle(
        color: selected ? Colors.black : Colors.white,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String suffix) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: Colors.white),
      cursorColor: _kAccent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: _kFieldBg,
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Colors.white54),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kAccent, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _slider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: _kAccent,
        inactiveTrackColor: Colors.white24,
        thumbColor: _kAccent,
        overlayColor: _kAccent.withValues(alpha: 0.2),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }

  Widget _sliderRow({required String title, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(value, style: const TextStyle(color: _kAccent, fontSize: 13)),
      ],
    );
  }
}
