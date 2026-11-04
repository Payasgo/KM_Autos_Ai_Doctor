import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/diagnostic_api.dart';
import 'scan_screen.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with WidgetsBindingObserver {
  final DiagnosticApi _api = DiagnosticApi();
  CameraController? controller;
  Timer? _scanTimer;
  bool initializing = true;
  bool capturing = false;
  bool analyzingFrame = false;
  String? error;
  String scanMessage = 'Starting camera…';
  List<dynamic> detections = [];
  List<dynamic> qualityNotes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera was found on this device.');
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final next = CameraController(
        selected,
        ResolutionPreset.medium,
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
        scanMessage = 'Live scan ready. Looking for engine components…';
      });
      _startLiveScan();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Unable to open camera: $e';
          initializing = false;
        });
      }
    }
  }

  void _startLiveScan() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _analyzeFrame();
    });
    _analyzeFrame();
  }

  Future<void> _analyzeFrame() async {
    final current = controller;
    if (!mounted || initializing || capturing || analyzingFrame ||
        current == null || !current.value.isInitialized ||
        current.value.isTakingPicture) {
      return;
    }
    analyzingFrame = true;
    XFile? frame;
    try {
      frame = await current.takePicture();
      final result = await _api.detectFrame(File(frame.path));
      if (!mounted) return;
      final rawDetections = result['component_detections'];
      final rawNotes = result['quality_notes'];
      setState(() {
        detections = rawDetections is List ? rawDetections : [];
        qualityNotes = rawNotes is List ? rawNotes : [];
        final status = result['model_status']?.toString() ?? 'unknown';
        scanMessage = status == 'not_configured'
            ? 'Camera is scanning, but an automotive model is not installed on the server.'
            : status == 'inference_completed'
                ? (detections.isEmpty
                    ? 'No components detected in this frame. This does not mean the car is fault-free.'
                    : 'Detected ${detections.length} component(s). These are visual labels, not faults.')
                : 'The model could not analyze this frame: $status';
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (frame != null) {
        try {
          await File(frame.path).delete();
        } catch (_) {}
      }
      analyzingFrame = false;
      if (mounted && error == null) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _scanTimer?.cancel();
      final old = controller;
      controller = null;
      old?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      setState(() {
        initializing = true;
        error = null;
        scanMessage = 'Restarting camera…';
      });
      _initialize();
    }
  }

  Future<void> _capture() async {
    final current = controller;
    if (current == null || !current.value.isInitialized ||
        capturing || analyzingFrame) return;
    _scanTimer?.cancel();
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
      if (mounted) {
        setState(() => capturing = false);
        _startLiveScan();
      }
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Live engine scan')),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: initializing
                  ? const CircularProgressIndicator()
                  : error != null && current == null
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
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Row(
                  children: [
                    Icon(
                      analyzingFrame ? Icons.radar : Icons.camera_alt,
                      color: analyzingFrame ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(scanMessage)),
                  ],
                ),
                if (error != null && current != null) ...[
                  const SizedBox(height: 6),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (qualityNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...qualityNotes.map((note) => Text('• $note')),
                ],
                const SizedBox(height: 8),
                const Text('Component detections', style: TextStyle(fontWeight: FontWeight.bold)),
                if (detections.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No component labels in the latest frame.'),
                  )
                else
                  ...detections.map((item) {
                    final map = item is Map ? item : <String, dynamic>{};
                    final label = map['label']?.toString() ?? 'Unknown component';
                    final confidence = map['confidence'];
                    final score = confidence is num ? (confidence * 100).toStringAsFixed(0) : '—';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.directions_car_outlined),
                      title: Text(label),
                      subtitle: Text('Model confidence: $score% • Visual label only'),
                    );
                  }),
                const SizedBox(height: 8),
                const Text(
                  'Frames are checked about every 3 seconds. Keep the engine OFF. '
                  'This is component recognition, not fault diagnosis. No bounding-box overlay is shown yet.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: initializing || capturing || analyzingFrame || current == null
                        ? null
                        : _capture,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(capturing ? 'Opening inspection…' : 'Capture full inspection'),
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
