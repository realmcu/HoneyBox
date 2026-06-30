import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transfer_provider.dart';
import '../../services/l2_file_transfer.dart';

class StreamPage extends ConsumerStatefulWidget {
  final String deviceName;
  final String deviceId;

  const StreamPage(
      {super.key, required this.deviceName, required this.deviceId});

  @override
  ConsumerState<StreamPage> createState() => _StreamPageState();
}

class _StreamPageState extends ConsumerState<StreamPage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _cameraReady = false;
  bool _streaming = false;
  bool _hasError = false;
  String _errorMsg = '';
  int _selectedCamera = 0; // 0 = back, 1 = front
  double _fps = 0;
  final List<int> _fpsTimestamps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (state == AppLifecycleState.resumed) {
      // Re-acquire the camera when returning to the foreground.
      if (controller == null || !controller.value.isInitialized) {
        _initCameras();
      }
      return;
    }
    // Leaving the foreground (paused/inactive/hidden/detached): stop streaming
    // and fully release the camera so it doesn't keep capturing — and flooding
    // logcat — while the app sits in the background.
    _streaming = false;
    if (controller != null) {
      _cameraController = null;
      _cameraReady = false;
      controller.dispose();
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (!mounted) return;
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMsg = '未找到摄像头';
        });
        return;
      }
      // Prefer back camera
      _selectedCamera = _cameras!
          .indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_selectedCamera < 0) _selectedCamera = 0;
      await _initCamera(_selectedCamera);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMsg = '摄像头初始化失败';
      });
    }
  }

  Future<void> _initCamera(int index) async {
    try {
      await _cameraController?.dispose();
      final cam = _cameras![index];
      _cameraController =
          CameraController(cam, ResolutionPreset.medium, enableAudio: false);
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMsg = '相机初始化失败';
      });
    }
  }

  void _toggleCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    final newIdx = _selectedCamera == 0 ? 1 : 0;
    setState(() {
      _selectedCamera = newIdx;
      _cameraReady = false;
    });
    _initCamera(newIdx);
  }

  void _startStreaming() {
    if (!_cameraReady) return;
    setState(() {
      _streaming = true;
      _fps = 0;
      _fpsTimestamps.clear();
    });
    _captureLoop();
  }

  void _stopStreaming() {
    setState(() => _streaming = false);
    ref.read(transferProgressProvider.notifier).abort();
  }

  Future<void> _waitForTransferToFinish() async {
    for (int i = 0; i < 300 && mounted && _streaming; i++) {
      final status = ref.read(transferProgressProvider).status;
      if (status == TransferStatus.done ||
          status == TransferStatus.error ||
          status == TransferStatus.idle) {
        ref.read(transferProgressProvider.notifier).reset();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    ref.read(transferProgressProvider.notifier).abort();
  }

  Future<void> _captureLoop() async {
    while (_streaming && mounted) {
      try {
        final xfile = await _cameraController!.takePicture();
        final file = File(xfile.path);
        final bytes = await file.readAsBytes();
        try {
          await file.delete();
        } catch (_) {}
        if (!_streaming || !mounted) break;

        ref
            .read(transferProgressProvider.notifier)
            .send(TYPE.raw, Uint8List.fromList(bytes), '');
        await _waitForTransferToFinish();
        if (!_streaming || !mounted) break;

        // FPS
        final now = DateTime.now().millisecondsSinceEpoch;
        _fpsTimestamps.add(now);
        while (_fpsTimestamps.length > 10) {
          _fpsTimestamps.removeAt(0);
        }
        if (_fpsTimestamps.length >= 2) {
          final span = (_fpsTimestamps.last - _fpsTimestamps.first) / 1000;
          if (span > 0 && mounted) {
            setState(() =>
                _fps = ((_fpsTimestamps.length - 1) / span * 10).round() / 10);
          }
        }
      } catch (_) {
        break;
      }
    }
    if (mounted) setState(() => _streaming = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streaming = false;
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('摄像头推流'),
        actions: [
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_android),
              tooltip: '切换摄像头',
              onPressed: _streaming ? null : _toggleCamera,
            ),
        ],
      ),
      body: _hasError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off, size: 64, color: cs.error),
                  const SizedBox(height: 16),
                  Text(_errorMsg, style: tt.titleMedium),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _errorMsg = '';
                      });
                      _initCameras();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _cameraReady && _cameraController!.value.isInitialized
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          child: CameraPreview(_cameraController!),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              const SizedBox(height: 16),
                              Text('正在启动摄像头…', style: tt.bodyMedium),
                            ],
                          ),
                        ),
                ),
                // Control panel
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        // Status row
                        Row(
                          children: [
                            Icon(Icons.videocam,
                                size: 16,
                                color: _streaming ? cs.error : cs.outline),
                            const SizedBox(width: 6),
                            Text(
                              _streaming ? '推流中' : '就绪',
                              style: tt.labelMedium?.copyWith(
                                color: _streaming ? cs.error : cs.outline,
                              ),
                            ),
                            if (_streaming) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.error,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (_streaming)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${_fps.toStringAsFixed(1)} fps',
                                    style: tt.labelSmall
                                        ?.copyWith(color: cs.primary)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Action button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: _streaming
                              ? FilledButton.icon(
                                  onPressed: _stopStreaming,
                                  icon: const Icon(Icons.stop_rounded),
                                  label: const Text('停止推流'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: cs.error,
                                    foregroundColor: cs.onError,
                                  ),
                                )
                              : FilledButton.icon(
                                  onPressed:
                                      _cameraReady ? _startStreaming : null,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('开始推流'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
