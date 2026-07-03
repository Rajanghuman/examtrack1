import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:examtrack/utils/image_resize_engine.dart';
import 'package:examtrack/data/photo_spec_presets.dart';

/// Photo & Signature Resizer — helps candidates resize their photo
/// or signature to match exact exam-portal pixel/file-size specs.
///
/// Design note: this tool is intentionally NOT AI-powered at
/// runtime. Resizing to an exact width/height and hitting a target
/// KB range is a deterministic, solved problem (crop + scale +
/// iterative JPEG quality search — see ImageResizeEngine), so doing
/// it locally is faster and more reliable than any live AI call
/// would be. The only place research/AI assistance was used is in
/// compiling the preset list (see photo_spec_presets.dart) — and
/// even there, every preset is editable/overridable by the user via
/// the manual fields below, never a hidden black box.
class PhotoResizerScreen extends StatefulWidget {
  const PhotoResizerScreen({super.key});

  @override
  State<PhotoResizerScreen> createState() => _PhotoResizerScreenState();
}

enum _Mode { photo, signature }

class _PhotoResizerScreenState extends State<PhotoResizerScreen> {
  _Mode _mode = _Mode.photo;

  final Map<_Mode, Uint8List?> _sourceBytes = {_Mode.photo: null, _Mode.signature: null};
  final Map<_Mode, Uint8List?> _croppedBytes = {_Mode.photo: null, _Mode.signature: null};
  final Map<_Mode, ResizeResult?> _result = {_Mode.photo: null, _Mode.signature: null};

  final Map<_Mode, TextEditingController> _widthCtrl = {
    _Mode.photo: TextEditingController(text: '200'),
    _Mode.signature: TextEditingController(text: '140'),
  };
  final Map<_Mode, TextEditingController> _heightCtrl = {
    _Mode.photo: TextEditingController(text: '230'),
    _Mode.signature: TextEditingController(text: '60'),
  };
  final Map<_Mode, TextEditingController> _minKBCtrl = {
    _Mode.photo: TextEditingController(text: '20'),
    _Mode.signature: TextEditingController(text: '10'),
  };
  final Map<_Mode, TextEditingController> _maxKBCtrl = {
    _Mode.photo: TextEditingController(text: '50'),
    _Mode.signature: TextEditingController(text: '20'),
  };

  PhotoSpecPreset? _activePreset;
  bool _isProcessing = false;

  @override
  void dispose() {
    for (final c in _widthCtrl.values) c.dispose();
    for (final c in _heightCtrl.values) c.dispose();
    for (final c in _minKBCtrl.values) c.dispose();
    for (final c in _maxKBCtrl.values) c.dispose();
    super.dispose();
  }

  Color get _accentColor => _mode == _Mode.photo ? const Color(0xFF1565C0) : const Color(0xFF6A1B9A);

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: source, imageQuality: 100);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _sourceBytes[_mode] = bytes;
      _croppedBytes[_mode] = null;
      _result[_mode] = null;
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: _accentColor),
            title: Text('Choose from Gallery', style: GoogleFonts.poppins(fontSize: 14)),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt_outlined, color: _accentColor),
            title: Text('Take a Photo', style: GoogleFonts.poppins(fontSize: 14)),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Future<void> _cropAuto() async {
    final src = _sourceBytes[_mode];
    if (src == null) return;
    setState(() => _croppedBytes[_mode] = src);
  }

  Future<void> _cropManual() async {
    final src = _sourceBytes[_mode];
    if (src == null) return;

    final width = int.tryParse(_widthCtrl[_mode]!.text) ?? 200;
    final height = int.tryParse(_heightCtrl[_mode]!.text) ?? 230;

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/resizer_source_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(src);

      final cropped = await ImageCropper().cropImage(
        sourcePath: tempFile.path,
        aspectRatio: CropAspectRatio(ratioX: width.toDouble(), ratioY: height.toDouble()),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: _mode == _Mode.photo ? 'Crop Photo' : 'Crop Signature',
            toolbarColor: _accentColor,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: _mode == _Mode.photo ? 'Crop Photo' : 'Crop Signature',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (cropped == null) return;

      final croppedBytes = await File(cropped.path).readAsBytes();
      setState(() => _croppedBytes[_mode] = croppedBytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open crop tool: $e', style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  void _applyPreset(PhotoSpecPreset preset) {
    setState(() {
      _activePreset = preset;
      if (_mode == _Mode.photo) {
        _widthCtrl[_mode]!.text = preset.photoWidth.toString();
        _heightCtrl[_mode]!.text = preset.photoHeight.toString();
        _minKBCtrl[_mode]!.text = preset.photoMinKB.toString();
        _maxKBCtrl[_mode]!.text = preset.photoMaxKB.toString();
      } else {
        _widthCtrl[_mode]!.text = preset.signatureWidth.toString();
        _heightCtrl[_mode]!.text = preset.signatureHeight.toString();
        _minKBCtrl[_mode]!.text = preset.signatureMinKB.toString();
        _maxKBCtrl[_mode]!.text = preset.signatureMaxKB.toString();
      }
    });
  }

  Future<void> _doResize() async {
    final src = _croppedBytes[_mode] ?? _sourceBytes[_mode];
    if (src == null) return;

    final width = int.tryParse(_widthCtrl[_mode]!.text);
    final height = int.tryParse(_heightCtrl[_mode]!.text);
    final minKB = int.tryParse(_minKBCtrl[_mode]!.text);
    final maxKB = int.tryParse(_maxKBCtrl[_mode]!.text);

    if (width == null || height == null || minKB == null || maxKB == null || width <= 0 || height <= 0 || minKB <= 0 || maxKB < minKB) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter valid width, height, and file size values.', style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: const Color(0xFFEF4444),
      ));
      return;
    }

    setState(() => _isProcessing = true);

    final result = await ImageResizeEngine.resize(
      sourceBytes: src,
      targetWidth: width,
      targetHeight: height,
      minKB: minKB,
      maxKB: maxKB,
    );

    if (!mounted) return;
    setState(() {
      _result[_mode] = result;
      _isProcessing = false;
    });
  }

  Future<File?> _getTempFile() async {
    final result = _result[_mode];
    if (result == null || !result.isSuccess || result.bytes == null) return null;
    final tempDir = await getTemporaryDirectory();
    final fileName = _mode == _Mode.photo ? 'photo_resized.jpg' : 'signature_resized.jpg';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(result.bytes!);
    return file;
  }

  Future<void> _saveToDevice() async {
    final result = _result[_mode];
    if (result == null || !result.isSuccess || result.bytes == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = _mode == _Mode.photo
          ? 'examtrack_photo_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : 'examtrack_signature_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(result.bytes!);

      final success = await GallerySaver.saveImage(file.path);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          success == true
              ? '✅ Saved to gallery successfully!'
              : '❌ Could not save to gallery. Try Share instead.',
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        backgroundColor: success == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Save failed: $e',
            style: GoogleFonts.poppins(fontSize: 12)),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  Future<void> _shareResult() async {
    final file = await _getTempFile();
    if (file == null) return;
    final result = _result[_mode]!;
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'My resized ${_mode == _Mode.photo ? "photo" : "signature"} for exam application — ${result.actualWidth}x${result.actualHeight}px, ${result.actualSizeKB}KB',
    );
  }

  void _reset() {
    setState(() {
      _sourceBytes[_mode] = null;
      _croppedBytes[_mode] = null;
      _result[_mode] = null;
      _activePreset = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        _header(),
        _modeToggle(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _uploadArea(),
              if (_sourceBytes[_mode] != null) ...[
                const SizedBox(height: 16),
                _cropOptions(),
                const SizedBox(height: 20),
                _presetRow(),
                const SizedBox(height: 16),
                _manualFields(),
                const SizedBox(height: 20),
                _resizeButton(),
              ],
              if (_result[_mode] != null) ...[
                const SizedBox(height: 20),
                _resultCard(),
              ],
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _header() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [_accentColor, _accentColor.withOpacity(0.75)]),
    ),
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16, right: 16, bottom: 16,
    ),
    child: Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back, color: Colors.white)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Photo & Signature Resizer', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        Text('Resize to exact exam portal specs', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
      ])),
      if (_sourceBytes[_mode] != null)
        IconButton(onPressed: _reset, icon: const Icon(Icons.refresh, color: Colors.white)),
    ]),
  );

  Widget _modeToggle() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Expanded(child: _modeButton('Photo', _Mode.photo, Icons.person_rounded)),
      const SizedBox(width: 10),
      Expanded(child: _modeButton('Signature', _Mode.signature, Icons.draw_rounded)),
    ]),
  );

  Widget _modeButton(String label, _Mode mode, IconData icon) {
    final selected = _mode == mode;
    final color = mode == _Mode.photo ? const Color(0xFF1565C0) : const Color(0xFF6A1B9A);
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : color)),
        ]),
      ),
    );
  }

  Widget _uploadArea() {
    final src = _sourceBytes[_mode];
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentColor.withOpacity(0.3), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: src == null
            ? Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_photo_alternate_outlined, size: 48, color: _accentColor.withOpacity(0.5)),
            const SizedBox(height: 10),
            Text('Tap to upload ${_mode == _Mode.photo ? "photo" : "signature"}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
            const SizedBox(height: 4),
            Text('From gallery or camera', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
          ]),
        )
            : ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(_croppedBytes[_mode] ?? src, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _cropOptions() => Row(children: [
    Expanded(child: OutlinedButton.icon(
      onPressed: _cropAuto,
      icon: const Icon(Icons.center_focus_strong, size: 16),
      label: Text('Auto Crop', style: GoogleFonts.poppins(fontSize: 12)),
      style: OutlinedButton.styleFrom(foregroundColor: _accentColor, side: BorderSide(color: _accentColor), padding: const EdgeInsets.symmetric(vertical: 10)),
    )),
    const SizedBox(width: 10),
    Expanded(child: ElevatedButton.icon(
      onPressed: _cropManual,
      icon: const Icon(Icons.crop, size: 16, color: Colors.white),
      label: Text('Manual Crop', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: _accentColor, padding: const EdgeInsets.symmetric(vertical: 10)),
    )),
  ]);

  Widget _presetRow() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Presets', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: PhotoSpecPresets.all.length,
          itemBuilder: (_, i) {
            final preset = PhotoSpecPresets.all[i];
            final isActive = _activePreset?.examName == preset.examName;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _applyPreset(preset),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? _accentColor : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isActive ? _accentColor : Colors.grey.shade300),
                  ),
                  child: Text(preset.examName, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF374151))),
                ),
              ),
            );
          },
        ),
      ),
      if (_activePreset != null) ...[
        const SizedBox(height: 10),
        _confidenceBanner(_activePreset!),
      ],
    ]);
  }

  Widget _confidenceBanner(PhotoSpecPreset preset) {
    Color bg, border, text;
    IconData icon;
    String label;
    switch (preset.confidence) {
      case 'HIGH':
        bg = const Color(0xFFE8F5E9); border = const Color(0xFF10B981); text = const Color(0xFF166534); icon = Icons.verified_rounded; label = 'High confidence';
        break;
      case 'MEDIUM':
        bg = const Color(0xFFFFF8E1); border = const Color(0xFFF59E0B); text = const Color(0xFF92400E); icon = Icons.info_rounded; label = 'Medium confidence — please verify';
        break;
      default:
        bg = const Color(0xFFFFEBEE); border = const Color(0xFFEF5350); text = const Color(0xFFC62828); icon = Icons.warning_amber_rounded; label = 'Low confidence — verify before use';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border, width: 1)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: text),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 2),
          Text(preset.sourceNote, style: GoogleFonts.poppins(fontSize: 10.5, color: text.withOpacity(0.85), height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _manualFields() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Target Size (you can edit these)', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _numberField('Width (px)', _widthCtrl[_mode]!)),
        const SizedBox(width: 10),
        Expanded(child: _numberField('Height (px)', _heightCtrl[_mode]!)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _numberField('Min Size (KB)', _minKBCtrl[_mode]!)),
        const SizedBox(width: 10),
        Expanded(child: _numberField('Max Size (KB)', _maxKBCtrl[_mode]!)),
      ]),
    ]);
  }

  Widget _numberField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: GoogleFonts.poppins(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _accentColor)),
      ),
    );
  }

  Widget _resizeButton() => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: _isProcessing ? null : _doResize,
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentColor,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isProcessing
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text('Resize Now', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    ),
  );

  Widget _resultCard() {
    final result = _result[_mode]!;
    if (!result.isSuccess) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEF5350))),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFD32F2F)),
          const SizedBox(width: 10),
          Expanded(child: Text(result.errorMessage ?? 'Something went wrong.', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFC62828)))),
        ]),
      );
    }

    final hitRange = result.hitTargetRange ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hitRange ? const Color(0xFF10B981) : const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(hitRange ? Icons.check_circle_rounded : Icons.info_rounded, color: hitRange ? const Color(0xFF10B981) : const Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 8),
          Text(hitRange ? 'Resized successfully' : 'Resized (close to target)',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(result.bytes!, height: 160, fit: BoxFit.contain),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _statChip(Icons.aspect_ratio, '${result.actualWidth} x ${result.actualHeight} px'),
          _statChip(Icons.sd_storage_outlined, '${result.actualSizeKB} KB'),
        ]),
        if (!hitRange) ...[
          const SizedBox(height: 8),
          Text(
            'Could not land exactly in your target KB range — the closest achievable size is shown. Try a less detailed photo or adjust the range slightly.',
            style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey.shade600, height: 1.4),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saveToDevice,
              icon: Icon(Icons.download_rounded, size: 18, color: _accentColor),
              label: Text('Save', style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _accentColor)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: _accentColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _shareResult,
              icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
              label: Text('Share', style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _statChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: _accentColor.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: _accentColor),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _accentColor)),
    ]),
  );
}