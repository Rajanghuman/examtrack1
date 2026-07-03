/// Exam-specific photo/signature size presets for the Photo/Signature
/// Resizer tool. Each preset just pre-fills the manual width/height/
/// file-size fields — users can always see and override these
/// numbers before resizing.
///
/// ============================================================
/// IMPORTANT — CONFIDENCE LEVELS:
///
///   HIGH    = numbers identical across 6+ independent sources
///   MEDIUM  = numbers identical across 2-3 independent sources
///   LOW     = only ONE source found; treat as a starting guess
///
/// Specs change between exam cycles. Always re-verify against the
/// official notification PDF before final submission.
/// Last researched: July 2026.
/// ============================================================

class PhotoSpecPreset {
  final String examName;
  final int photoWidth;
  final int photoHeight;
  final int photoMinKB;
  final int photoMaxKB;
  final int signatureWidth;
  final int signatureHeight;
  final int signatureMinKB;
  final int signatureMaxKB;
  final String confidence; // 'HIGH' | 'MEDIUM' | 'LOW'
  final String sourceNote;

  const PhotoSpecPreset({
    required this.examName,
    required this.photoWidth,
    required this.photoHeight,
    required this.photoMinKB,
    required this.photoMaxKB,
    required this.signatureWidth,
    required this.signatureHeight,
    required this.signatureMinKB,
    required this.signatureMaxKB,
    required this.confidence,
    required this.sourceNote,
  });
}

class PhotoSpecPresets {
  static const List<PhotoSpecPreset> all = [

    // ── Banking ─────────────────────────────────────────────
    PhotoSpecPreset(
      examName: 'IBPS PO',
      photoWidth: 200, photoHeight: 230,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 140, signatureHeight: 60,
      signatureMinKB: 10, signatureMaxKB: 20,
      confidence: 'HIGH',
      sourceNote: 'Confirmed identical across 8+ independent sources (2026 research).',
    ),
    PhotoSpecPreset(
      examName: 'IBPS Clerk',
      photoWidth: 200, photoHeight: 230,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 140, signatureHeight: 60,
      signatureMinKB: 10, signatureMaxKB: 20,
      confidence: 'HIGH',
      sourceNote: 'Same specs as IBPS PO — confirmed across multiple sources.',
    ),
    PhotoSpecPreset(
      examName: 'SBI PO',
      photoWidth: 200, photoHeight: 230,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 140, signatureHeight: 60,
      signatureMinKB: 10, signatureMaxKB: 20,
      confidence: 'HIGH',
      sourceNote: 'Confirmed across 6+ sources including SBI official portal specs (April 2026). Same specs apply to SBI Clerk, SBI SO, and SBI CBO.',
    ),
    PhotoSpecPreset(
      examName: 'SBI Clerk',
      photoWidth: 200, photoHeight: 230,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 140, signatureHeight: 60,
      signatureMinKB: 10, signatureMaxKB: 20,
      confidence: 'HIGH',
      sourceNote: 'Same specs as SBI PO — confirmed across multiple sources.',
    ),

    // ── SSC ──────────────────────────────────────────────────
    PhotoSpecPreset(
      examName: 'SSC CGL',
      photoWidth: 200, photoHeight: 230,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 140, signatureHeight: 60,
      signatureMinKB: 10, signatureMaxKB: 20,
      confidence: 'MEDIUM',
      sourceNote:
      'Most sources agree on 200x230px and 20-50KB for photo. '
          'Signature dimensions vary across sources (140x60 vs 236x79). '
          'Note: SSC CGL OTR now uses live webcam capture — a separately '
          'uploaded photo may not be required. Check your specific notification.',
    ),
    PhotoSpecPreset(
      examName: 'SSC CHSL',
      photoWidth: 200, photoHeight: 230,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 140, signatureHeight: 60,
      signatureMinKB: 10, signatureMaxKB: 20,
      confidence: 'MEDIUM',
      sourceNote:
      'Multiple sources confirm 200x230px, 20-50KB. Signature specs '
          'confirmed as 4.0cm x 2.0cm, 10-20KB across official sources.',
    ),
    PhotoSpecPreset(
      examName: 'SSC GD',
      photoWidth: 200, photoHeight: 230,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 140, signatureHeight: 60,
      signatureMinKB: 10, signatureMaxKB: 20,
      confidence: 'MEDIUM',
      sourceNote: 'SSC GD follows same SSC-standard specs. Signature: 4.0cm x 2.0cm, 10-20KB confirmed by Testbook (June 2026).',
    ),
    PhotoSpecPreset(
      examName: 'SSC MTS',
      photoWidth: 200, photoHeight: 230,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 140, signatureHeight: 60,
      signatureMinKB: 10, signatureMaxKB: 20,
      confidence: 'MEDIUM',
      sourceNote: 'All SSC exams (CGL/CHSL/GD/MTS/CPO) use the same photo spec. Verify against your specific notification.',
    ),

    // ── Railway ──────────────────────────────────────────────
    PhotoSpecPreset(
      examName: 'RRB NTPC',
      photoWidth: 200, photoHeight: 230,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 140, signatureHeight: 60,
      signatureMinKB: 10, signatureMaxKB: 20,
      confidence: 'MEDIUM',
      sourceNote:
      'Photo specs vary significantly across sources (200x230 vs 320x240, '
          '20-50KB vs 30-70KB). Most commonly cited: 200x230px, 20-50KB. '
          'Always verify against your specific RRB zone notification before applying.',
    ),

    // ── Police ────────────────────────────────────────────────
    PhotoSpecPreset(
      examName: 'Punjab Police',
      photoWidth: 200, photoHeight: 240,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 140, signatureHeight: 80,
      signatureMinKB: 10, signatureMaxKB: 20,
      confidence: 'LOW',
      sourceNote: 'Only one independent source found during research — treat as a starting point, not a confirmed spec. Verify against official notification.',
    ),
    PhotoSpecPreset(
      examName: 'Haryana Police',
      photoWidth: 138, photoHeight: 177,
      photoMinKB: 20, photoMaxKB: 40,
      signatureWidth: 138, signatureHeight: 59,
      signatureMinKB: 10, signatureMaxKB: 30,
      confidence: 'LOW',
      sourceNote: 'Only one independent source found during research — treat as a starting point, not a confirmed spec.',
    ),
    PhotoSpecPreset(
      examName: 'UP Police',
      photoWidth: 180, photoHeight: 225,
      photoMinKB: 20, photoMaxKB: 50,
      signatureWidth: 200, signatureHeight: 80,
      signatureMinKB: 5, signatureMaxKB: 20,
      confidence: 'LOW',
      sourceNote: 'UP Police OTR portal specs from ExamMint (2026). Only one source — verify against the official OTR portal notification.',
    ),

  ];

  static PhotoSpecPreset? byExamName(String name) {
    try {
      return all.firstWhere((p) => p.examName == name);
    } catch (_) {
      return null;
    }
  }
}