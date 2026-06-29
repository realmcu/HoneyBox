import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/transfer_provider.dart';
import '../../services/l2_file_transfer.dart';
import '../shared/file_send_layout.dart';

/// Page for sending videos to the connected badge device.
class VideoPage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const VideoPage({
    super.key,
    required this.deviceName,
    required this.deviceId,
  });

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage> {
  XFile? _selectedVideo;
  final _picker = ImagePicker();

  @override
  void dispose() {
    final state = ref.read(transferProgressProvider);
    if (state.status == TransferStatus.sending) {
      ref.read(transferProgressProvider.notifier).abort();
    }
    super.dispose();
  }

  /// Open the device gallery and let the user pick a video.
  Future<void> _pickVideo() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      final file = File(video.path);
      final length = await file.length();

      // 10 MB limit.
      if (length > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件过大，建议压缩后发送')),
        );
        return;
      }

      setState(() => _selectedVideo = video);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择视频失败: $e')),
      );
    }
  }

  /// Read the selected file bytes and kick off the BLE transfer.
  Future<void> _send() async {
    final video = _selectedVideo;
    if (video == null) return;

    try {
      final file = File(video.path);
      final bytes = await file.readAsBytes();
      final name = video.name;

      ref.read(transferProgressProvider.notifier).send(
            TYPE.video,
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
      appBar: AppBar(title: const Text('发送视频')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FileSendLayout(
          fileName: _selectedVideo?.name,
          fileSize: null,
          transferState: transferState,
          onPick: _pickVideo,
          onSend: _send,
          onCancel: () => ref.read(transferProgressProvider.notifier).abort(),
          hintText: '点击选择视频',
          pickIcon: Icons.videocam_outlined,
        ),
      ),
    );
  }
}
