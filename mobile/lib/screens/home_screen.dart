import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'scan_screen.dart';
import 'camera_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final picker = ImagePicker();

  Future<void> _pick(ImageSource source) async {
    final XFile? file = await picker.pickImage(
      source: source, imageQuality: 88, maxWidth: 2200, maxHeight: 2200,
    );
    if (file == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ScanScreen(image: File(file.path)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Car Doctor'), centerTitle: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF164E63), Color(0xFF176B5B)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.car_repair, size: 42),
                  SizedBox(height: 18),
                  Text('Your car. A smarter first look.',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Capture an engine-bay photo to receive a preliminary visual inspection.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Start an inspection',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.camera_alt_outlined,
              title: 'Take a photo',
              subtitle: 'Use your phone camera',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScanScreen())),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.photo_library_outlined,
              title: 'Upload a photo',
              subtitle: 'Choose an existing engine-bay image',
              onTap: () => _pick(ImageSource.gallery),
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.health_and_safety_outlined, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Safety first', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Switch the engine off, remove the key, and let hot parts cool before taking photos. Never touch belts, fans, hot components, or high-voltage EV parts.'),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('Visual screening only • Not a substitute for a mechanic or OBD-II diagnosis',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
