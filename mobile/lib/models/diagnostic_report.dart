class DiagnosticReport {
  final String scanId;
  final String createdAt;
  final String modelStatus;
  final String summary;
  final String severity;
  final List findings;
  final List detections;
  final List qualityNotes;
  final List nextSteps;
  final String disclaimer;

  DiagnosticReport.fromJson(Map<String, dynamic> json)
      : scanId = json['scan_id']?.toString() ?? '',
        createdAt = json['created_at']?.toString() ?? '',
        modelStatus = json['model_status']?.toString() ?? 'unknown',
        summary = json['summary']?.toString() ?? 'No summary available.',
        severity = json['severity']?.toString() ?? 'unknown',
        findings = List.from(json['findings'] ?? const []),
        detections = List.from(json['component_detections'] ?? const []),
        qualityNotes = List.from(json['quality_notes'] ?? const []),
        nextSteps = List.from(json['next_steps'] ?? const []),
        disclaimer = json['disclaimer']?.toString() ?? '';
}
