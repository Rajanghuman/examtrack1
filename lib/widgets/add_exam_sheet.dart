import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:examtrack/services/progress_service.dart';

/// Bottom sheet that lets users manually add an exam to their
/// history (for exams taken outside the app, or results received
/// after applying). Called from ProfileProgressSection.
class AddExamSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const AddExamSheet({super.key, required this.onAdded});

  @override
  State<AddExamSheet> createState() => _AddExamSheetState();
}

class _AddExamSheetState extends State<AddExamSheet> {
  final _examController = TextEditingController();
  String _status = 'applied';
  bool _saving = false;

  static const List<Map<String, dynamic>> _statuses = [
    {'value': 'applied',  'label': 'Applied',  'icon': '📨', 'color': 0xFFF59E0B},
    {'value': 'appeared', 'label': 'Appeared', 'icon': '✍️', 'color': 0xFF1565C0},
    {'value': 'passed',   'label': 'Passed',   'icon': '✅', 'color': 0xFF10B981},
    {'value': 'failed',   'label': 'Failed',   'icon': '❌', 'color': 0xFFEF4444},
  ];

  @override
  void dispose() {
    _examController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final examName = _examController.text.trim();
    if (examName.isEmpty) return;

    setState(() => _saving = true);

    await ProgressService.addExamHistory(
      examName: examName,
      status: _status,
      source: 'manual',
    );

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    widget.onAdded();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),
        Text('Add Exam to History', style: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
        const SizedBox(height: 16),
        TextField(
          controller: _examController,
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Exam Name (e.g. SSC CGL 2025)',
            labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
            filled: true, fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0))),
          ),
        ),
        const SizedBox(height: 16),
        Text('Status', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 8),
        Row(children: _statuses.map((s) {
          final isSelected = _status == s['value'];
          final color = Color(s['color'] as int);
          return Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _status = s['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? color : color.withOpacity(0.2)),
                ),
                child: Column(children: [
                  Text(s['icon'] as String, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(s['label'] as String, style: GoogleFonts.poppins(
                      fontSize: 9, fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : color)),
                ]),
              ),
            ),
          ));
        }).toList()),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Save to History', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        )),
      ]),
    );
  }
}