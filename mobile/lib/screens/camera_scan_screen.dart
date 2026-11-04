import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'scan_screen.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  bool initializing = true;
  bool capturing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    if (capturing) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera was found on this device.');
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        selected, ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      final old = controller;
      controller = next;
      await old?.dispose();
      setState(() {
        initializing = false;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Unable to open camera: $e';
          initializing = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (capturing) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final old = controller;
      controller = null;
      old?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      setState(() {
        initializing = true;
        error = null;
      });
      _initialize();
    }
  }

  Future<void> _capture() async {
    final current = controller;
    if (current == null || !current.value.isInitialized || capturing) return;
    setState(() => capturing = true);
    try {
      final photo = await current.takePicture();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ScanScreen(image: File(photo.path))),
      );
    } catch (e) {
      if (mounted) setState(() => error = 'Could not capture image: $e');
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Live engine camera')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: initializing
                  ? const CircularProgressIndicator()
                  : error != null
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(error!, textAlign: TextAlign.center),
                        )
                      : current != null && current.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: current.value.aspectRatio,
                              child: CameraPreview(current),
                            )
                          : const Text('Camera unavailable. Reopen this screen to retry.'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                const Text(
                  'Keep the engine OFF. Frame the engine bay clearly, avoid glare, and never place your hands near moving or hot parts.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: initializing || capturing || current == null ? null : _capture,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(capturing ? 'Capturing…' : 'Capture and inspect'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
