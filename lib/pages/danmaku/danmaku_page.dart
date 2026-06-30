import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transfer_provider.dart';
import '../../services/l2_file_transfer.dart';

class DanmakuPage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const DanmakuPage(
      {super.key, required this.deviceName, required this.deviceId});

  @override
  ConsumerState<DanmakuPage> createState() => _DanmakuPageState();
}

class _DanmakuPageState extends ConsumerState<DanmakuPage>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  bool _sending = false;
  late AnimationController _sendAnimController;
  late Animation<double> _sendAnimation;

  @override
  void initState() {
    super.initState();
    _sendAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sendAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _sendAnimController, curve: Curves.easeInOut),
    );
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _sendAnimController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _sendDanmaku() {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _sendAnimController.forward().then((_) {
      if (mounted) _sendAnimController.reverse();
    });
    setState(() => _sending = true);

    final bytes = Uint8List.fromList(utf8.encode(text));
    ref.read(transferProgressProvider.notifier).send(TYPE.raw, bytes, '');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    ref.listen<TransferState>(transferProgressProvider, (prev, next) {
      if (!mounted) return;
      if (next.status == TransferStatus.done) {
        setState(() {
          _sending = false;
          _controller.clear();
        });
        ref.read(transferProgressProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发送成功')),
        );
      } else if (next.status == TransferStatus.error) {
        setState(() => _sending = false);
        ref.read(transferProgressProvider.notifier).reset();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage ?? '发送失败')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('发送弹幕')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: TextField(
                  controller: _controller,
                  maxLength: 60,
                  maxLines: 4,
                  textAlign: TextAlign.center,
                  style: tt.titleLarge?.copyWith(height: 1.6),
                  decoration: InputDecoration(
                    hintText: '输入弹幕内容…',
                    hintStyle: tt.bodyLarge?.copyWith(color: cs.outline),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
            ),
            // Character counter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('${_controller.text.length}/60',
                    style: tt.labelMedium?.copyWith(
                        color: _controller.text.length > 50
                            ? cs.error
                            : cs.outline)),
              ),
            ),
            const SizedBox(height: 16),
            // Send button
            AnimatedBuilder(
              animation: _sendAnimation,
              builder: (context, child) => Transform.scale(
                scale: _sendAnimation.value,
                child: child,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: (_controller.text.trim().isEmpty || _sending)
                      ? null
                      : _sendDanmaku,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? '发送中…' : '发送弹幕'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
