import 'dart:io';
import 'package:flutter/material.dart';
import '../models/diagnostic_report.dart';
import '../services/diagnostic_api.dart';

class ScanScreen extends StatefulWidget {
  final File image;
  const ScanScreen({super.key, required this.image});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final api = DiagnosticApi();
  final make = TextEditingController();
  final model = TextEditingController();
  final year = TextEditingController();
  bool loading = false;
  String? error;
  DiagnosticReport? report;

  Future<void> _run() async {
    setState(() { loading = true; error = null; report = null; });
    try {
      final result = await api.diagnose(widget.image,
        make: make.text, model: model.text, year: year.text);
      if (mounted) setState(() => report = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    make.dispose(); model.dispose(); year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspect engine photo')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(widget.image, height: 230, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 18),
          const Text('Vehicle details (optional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(controller: make, decoration: const InputDecoration(labelText: 'Make (e.g. Toyota)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: model, decoration: const InputDecoration(labelText: 'Model (e.g. Corolla)', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: loading ? null : _run,
            icon: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.document_scanner_outlined),
            label: Text(loading ? 'Inspecting image…' : 'Run AI inspection'),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            _MessageCard(icon: Icons.error_outline, color: Colors.redAccent, text: error!),
          ],
          if (report != null) ...[
            const SizedBox(height: 20),
            _ReportView(report: report!),
          ],
        ],
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  final DiagnosticReport report;
  const _ReportView({required this.report});

  @override
  Widget build(BuildContext context) {
    final statusColor = report.severity == 'high' ? Colors.redAccent : Colors.amber;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Inspection report', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      _MessageCard(icon: Icons.info_outline, color: statusColor, text: report.summary),
      const SizedBox(height: 12),
      Text('Detector status: ${report.modelStatus}', style: Theme.of(context).textTheme.bodySmall),
      if (report.qualityNotes.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('Image quality notes', style: TextStyle(fontWeight: FontWeight.bold)),
        ...report.qualityNotes.map((e) => _Bullet(text: e.toString())),
      ],
      if (report.detections.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('Detected labels (not confirmed faults)', style: TextStyle(fontWeight: FontWeight.bold)),
        ...report.detections.map((e) => _Bullet(text: '${e['label']} • confidence ${e['confidence']}')),
      ],
      const SizedBox(height: 12),
      const Text('Recommended next steps', style: TextStyle(fontWeight: FontWeight.bold)),
      ...report.nextSteps.map((e) => _Bullet(text: e.toString())),
      const SizedBox(height: 12),
      _MessageCard(icon: Icons.health_and_safety, color: Colors.blueAccent, text: report.disclaimer),
      const SizedBox(height: 20),
    ]);
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('•  '), Expanded(child: Text(text)),
    ]),
  );
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _MessageCard({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color), const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    ),
  );
}
