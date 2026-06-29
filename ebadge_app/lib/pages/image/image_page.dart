import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/transfer_provider.dart';
import '../../services/l2_file_transfer.dart';
import '../shared/file_send_layout.dart';

/// Page for sending images (JPEG/PNG) to the connected badge device.
class ImagePage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const ImagePage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends ConsumerState<ImagePage> {
  XFile? _selectedImage;
  final _picker = ImagePicker();

  @override
  void dispose() {
    // Abort any in-flight transfer when leaving the page.
    final state = ref.read(transferProgressProvider);
    if (state.status == TransferStatus.sending) {
      ref.read(transferProgressProvider.notifier).abort();
    }
    super.dispose();
  }

  /// Open the device gallery and let the user pick an image.
  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // Reject animated GIF files selected through the image picker.
      final name = image.name.toLowerCase();
      if (name.endsWith('.gif')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请使用 GIF 功能发送 GIF 文件')),
        );
        return;
      }

      final file = File(image.path);
      final length = await file.length();

      // 10 MB limit.
      if (length > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件过大，建议压缩后发送')),
        );
        return;
      }

      setState(() => _selectedImage = image);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败: $e')),
      );
    }
  }

  /// Read the selected file and kick off the BLE transfer.
  Future<void> _send() async {
    final image = _selectedImage;
    if (image == null) return;

    try {
      final file = File(image.path);
      final bytes = await file.readAsBytes();
      final name = image.name;

      ref.read(transferProgressProvider.notifier).send(
            TYPE.image,
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

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(transferProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('发送图片')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FileSendLayout(
          fileName: _selectedImage?.name,
          fileSize: null, // computed lazily when the progress appears
          transferState: transferState,
          onPick: _pickImage,
          onSend: _send,
          onCancel: () => ref.read(transferProgressProvider.notifier).abort(),
          hintText: '点击选择图片',
          pickIcon: Icons.image_outlined,
        ),
      ),
    );
  }
}
