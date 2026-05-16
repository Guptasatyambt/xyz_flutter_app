import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/driver_models.dart';
import '../services/driver_service.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  DriverProfile? _profile;
  List<DriverDocument> _docs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        DriverService.getProfile(),
        DriverService.listDocuments(),
      ]);
      setState(() {
        _profile = results[0] as DriverProfile;
        _docs    = results[1] as List<DriverDocument>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DriverDocument? _docFor(String type) {
    try {
      return _docs.firstWhere((d) => d.type == type);
    } catch (_) {
      return null;
    }
  }

  Future<void> _uploadDoc(String type) async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final picked = await picker.pickImage(source: choice, imageQuality: 85);
    if (picked == null || !mounted) return;

    try {
      final doc = await DriverService.uploadDocument(
        filePath: picked.path,
        type: type,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${doc.typeLabel} uploaded successfully')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _viewDoc(DriverDocument doc) {
    final url = doc.url;
    if (url == null || url.isEmpty) return;

    final isImage = doc.mimeType.startsWith('image/');
    if (isImage) {
      _showImagePreview(doc.typeLabel, url);
    } else {
      _launchUrl(url);
    }
  }

  void _showImagePreview(String title, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
                errorBuilder: (_, _, _) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 48),
                      SizedBox(height: 8),
                      Text('Could not load image',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open this file')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'KYC & Documents',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: BackButton(color: const Color(0xFF1A1A2E)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildKycStatusCard(),
                      const SizedBox(height: 20),
                      const Text(
                        'Required Documents',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...kRequiredDocTypes.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DocCard(
                            type: t,
                            doc: _docFor(t),
                            onUpload: () => _uploadDoc(t),
                            onView: () {
                              final d = _docFor(t);
                              if (d != null) _viewDoc(d);
                            },
                            onDownload: () {
                              final u = _docFor(t)?.url;
                              if (u != null && u.isNotEmpty) _launchUrl(u);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Optional Documents',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...kAllDocTypes
                          .where((t) => !kRequiredDocTypes.contains(t))
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _DocCard(
                                type: t,
                                doc: _docFor(t),
                                onUpload: () => _uploadDoc(t),
                                onView: () {
                                  final d = _docFor(t);
                                  if (d != null) _viewDoc(d);
                                },
                                onDownload: () {
                                  final u = _docFor(t)?.url;
                                  if (u != null && u.isNotEmpty) _launchUrl(u);
                                },
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildKycStatusCard() {
    final p = _profile!;
    final (bg, fg, icon) = switch (p.kycStatus) {
      'APPROVED'     => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32), Icons.verified),
      'REJECTED'     => (const Color(0xFFFFEBEE), const Color(0xFFC62828), Icons.cancel),
      'UNDER_REVIEW' => (const Color(0xFFFFF8E1), const Color(0xFFF57F17), Icons.hourglass_top),
      _              => (const Color(0xFFFFF3E0), const Color(0xFFE65100), Icons.upload_file),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KYC Status: ${p.kycStatusLabel}',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (p.isRejected && p.rejectionReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.rejectionReason!,
                    style: TextStyle(color: fg, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Document card ──────────────────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final String type;
  final DriverDocument? doc;
  final VoidCallback onUpload;
  final VoidCallback onView;
  final VoidCallback onDownload;

  const _DocCard({
    required this.type,
    required this.doc,
    required this.onUpload,
    required this.onView,
    required this.onDownload,
  });

  String get _typeLabel => switch (type) {
        'DRIVING_LICENSE'    => 'Driving License',
        'AADHAAR'            => 'Aadhaar Card',
        'PAN'                => 'PAN Card',
        'VEHICLE_RC'         => 'Vehicle RC',
        'VEHICLE_INSURANCE'  => 'Vehicle Insurance',
        'PROFILE_PHOTO'      => 'Profile Photo',
        _                    => type,
      };

  bool get _hasUrl => doc?.url != null && doc!.url!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final hasDoc      = doc != null;
    final isApproved  = doc?.isApproved ?? false;
    final isRejected  = doc?.isRejected ?? false;
    final isImage     = doc?.mimeType.startsWith('image/') ?? false;

    final (statusColor, statusText, statusIcon) = switch (true) {
      _ when isApproved => (
          const Color(0xFF2E7D32),
          'Approved',
          Icons.check_circle,
        ),
      _ when isRejected => (
          const Color(0xFFC62828),
          'Rejected',
          Icons.cancel,
        ),
      _ when hasDoc => (
          const Color(0xFFF57F17),
          'Under Review',
          Icons.hourglass_top,
        ),
      _ => (
          const Color(0xFF9E9E9E),
          'Not Uploaded',
          Icons.upload_file_outlined,
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: icon + label + status ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isImage ? Icons.image_outlined : Icons.description_outlined,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _typeLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(fontSize: 12, color: statusColor),
                          ),
                        ],
                      ),
                      if (isRejected && doc?.rejectionReason != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          doc!.rejectionReason!,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFC62828)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Action buttons row ───────────────────────────────────────────
          if (_hasUrl || !isApproved)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  if (_hasUrl) ...[
                    _ActionChip(
                      icon: isImage ? Icons.image_search : Icons.open_in_new,
                      label: isImage ? 'Preview' : 'Open',
                      onTap: onView,
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: Icons.download_outlined,
                      label: 'Download',
                      onTap: onDownload,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!isApproved)
                    _ActionChip(
                      icon: hasDoc ? Icons.upload : Icons.upload_file,
                      label: hasDoc ? 'Re-upload' : 'Upload',
                      onTap: onUpload,
                      primary: !_hasUrl,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Action chip ────────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF5C6BC0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? accent : Colors.white,
          border: Border.all(
            color: primary ? accent : const Color(0xFFBDBDBD),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13,
                color: primary ? Colors.white : const Color(0xFF616161)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: primary ? Colors.white : const Color(0xFF616161),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
