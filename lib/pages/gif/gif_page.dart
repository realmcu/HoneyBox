import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/transfer_provider.dart';
import '../../services/l2_file_transfer.dart';
import '../shared/file_send_layout.dart';

/// Page for sending GIF files to the connected badge device.
class GifPage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const GifPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<GifPage> createState() => _GifPageState();
}

class _GifPageState extends ConsumerState<GifPage> {
  PlatformFile? _selectedFile;

  @override
  void dispose() {
    final state = ref.read(transferProgressProvider);
    if (state.status == TransferStatus.sending) {
      ref.read(transferProgressProvider.notifier).abort();
    }
    super.dispose();
  }

  /// Open the system file picker filtered to .gif.
  Future<void> _pickGif() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gif'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // Validate the extension (belt-and-suspenders with the filter above).
      final name = file.name.toLowerCase();
      if (!name.endsWith('.gif')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择 GIF 文件')),
        );
        return;
      }

      final size = file.size;

      // 10 MB limit.
      if (size > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件过大，建议压缩后发送')),
        );
        return;
      }

      setState(() => _selectedFile = file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择 GIF 失败: $e')),
      );
    }
  }

  /// Read the selected GIF bytes and kick off the BLE transfer.
  Future<void> _send() async {
    final file = _selectedFile;
    if (file == null) return;

    try {
      final bytes = await _readFileBytes(file);
      final name = file.name;

      ref.read(transferProgressProvider.notifier).send(
            TYPE.raw,
            bytes,
            name,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取文件失败: $e')),
      );
    }
  }

  /// Read bytes from a [PlatformFile]. Falls back via path or buffer.
  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) {
      return await File(file.path!).readAsBytes();
    }
    throw Exception('无法读取文件内容');
  }

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(transferProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('发送 GIF')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FileSendLayout(
          fileName: _selectedFile?.name,
          fileSize: _selectedFile?.size.toInt(),
          transferState: transferState,
          onPick: _pickGif,
          onSend: _send,
          onCancel: () => ref.read(transferProgressProvider.notifier).abort(),
          hintText: '点击选择 GIF',
          pickIcon: Icons.gif_box_outlined,
        ),
      ),
    );
  }
}
