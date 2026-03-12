import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
import 'paywall_screen.dart';
import 'modern_loading_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

// --- ULTRA CLEAN RESULT VIEW ---
class ResultView extends StatefulWidget {
  final File? imageFile;
  final String? imageUrl;
  final Map<String, dynamic> resultData;
  final VoidCallback? onBackPressed;
  final VoidCallback? onDelete;

  const ResultView({
    super.key,
    this.imageFile,
    this.imageUrl,
    required this.resultData,
    this.onBackPressed,
    this.onDelete,
  });

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  bool _showHeatmap = true;

  late ImageProvider _baseImage;
  ImageProvider? _heatmapImage;

  @override
  void initState() {
    super.initState();

    if (widget.imageFile != null) {
      _baseImage = FileImage(widget.imageFile!);
    } else {
      _baseImage = NetworkImage(widget.imageUrl!);
    }

    if (widget.resultData['heatmap'] != null) {
      _heatmapImage = MemoryImage(base64Decode(widget.resultData['heatmap']));
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.resultData['report'];
    final mode = widget.resultData['mode'] ?? 'chest';
    final hasHeatmap = _heatmapImage != null;

    // --- 1. Extract AI Message ---
    final String? aiMessage = widget.resultData['ai_message'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- MINIMALIST HEADER ---
          if (widget.onBackPressed != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0, left: 8.0, bottom: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 24, color: Colors.black87),
                onPressed: widget.onBackPressed,
              ),
            ),

          // --- EDGE-TO-EDGE IMAGE ---
          Stack(
            children: [
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: (_showHeatmap && hasHeatmap)
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Image(
                    image: _baseImage,
                    width: double.infinity,
                    fit: BoxFit.cover),
                secondChild: hasHeatmap
                    ? Image(
                        image: _heatmapImage!,
                        width: double.infinity,
                        fit: BoxFit.cover)
                    : const SizedBox(height: 300),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SOCIAL MEDIA STYLE ACTION ROW ---
                if (hasHeatmap) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Clean toggle button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showHeatmap = !_showHeatmap;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                _showHeatmap
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.black87,
                                size: 26,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _showHeatmap
                                    ? "hide_thermal".tr()
                                    : "show_thermal".tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- MOVED: Info Button is now next to the toggle ---
                      IconButton(
                        icon: const Icon(Icons.info_outline,
                            color: Colors.black87, size: 26),
                        onPressed: () {
                          // ... Keep your existing showDialog code here ...
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: Text("heatmap_info_title".tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              content: Text("heatmap_info".tr(),
                                  style: const TextStyle(
                                      height: 1.4, color: Colors.black87)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text("Got it",
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const Spacer(),

                      // --- NEW: Delete Button on the far right ---
                      if (widget.onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.black87, size: 28),
                          onPressed: widget.onDelete,
                        ),
                    ],
                  ),
                  const Divider(
                      height: 24, thickness: 1, color: Color(0xFFEEEEEE)),
                ],

                // --- 2. VLM AI MESSAGE SECTION ---
                if (aiMessage != null && aiMessage.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FC), // Soft medical blue tint
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5EDF8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                color: Color(0xFF2B5C9A), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "ai_insights".tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          aiMessage,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // --- SOTA PARSING LOGIC WITH CLEAN TILES ---
                Text(
                  "ui_scores".tr(),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),

                if (mode == 'bone') ...[
                  _buildResultTile(
                      translateMedicalTerm(report['prediction']?.toString()),
                      (report['confidence'] as num?)?.toDouble() ?? 0.0),
                ] else if (mode == 'chest' && report is List) ...[
                  for (var finding in report)
                    _buildResultTile(
                        translateMedicalTerm(finding['finding']?.toString()),
                        (finding['confidence'] as num?)?.toDouble() ?? 0.0),
                ],

                const SizedBox(height: 32),

                // --- MINIMALIST WARNING BANNER ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "ui_warning_doctor".tr(),
                          style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 13,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40), // Bottom padding
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---> THE NEW CRISP TABULAR TILE <---
  Widget _buildResultTile(String finding, double confidence) {
    String score = "${confidence.toStringAsFixed(1)}%";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              finding,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            score,
            style: const TextStyle(
              color: Color.fromARGB(255, 0, 72, 255),
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

// --- MAIN ANALYZE SCREEN ---
class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  bool _isInitializingProfile = true;
  Map<String, dynamic>? _results;
  final ApiService _apiService = ApiService();

  bool _isPressed = false;

  final String _developerEmail = '20035241@gmail.com';

  @override
  void initState() {
    super.initState();
    _ensureUserAccountExists();
  }

  Future<String> _getUniqueDeviceId() async {
    String deviceId = 'unknown_device';
    try {
      if (Platform.isAndroid) {
        const androidIdPlugin = AndroidId();
        deviceId = await androidIdPlugin.getId() ?? 'unknown_android';
      } else if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
      }
    } catch (e) {
      print("Cihaz ID alınamadı: $e");
    }
    return deviceId;
  }

  Future<void> _ensureUserAccountExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userDocRef.get();

    if (userDoc.exists) {
      if (mounted) setState(() => _isInitializingProfile = false);
      return;
    }

    final deviceId = await _getUniqueDeviceId();
    final deviceDocRef =
        FirebaseFirestore.instance.collection('devices').doc(deviceId);
    final deviceDoc = await deviceDocRef.get();

    int startingCredits = 2;

    if (deviceDoc.exists) {
      startingCredits = 0;
    } else {
      await deviceDocRef.set({
        'firstUsedBy': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await userDocRef.set({
      'email': user.email,
      'credits': startingCredits,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) setState(() => _isInitializingProfile = false);
  }

  void _showOutOfCreditsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("ui_out_of_credits_title".tr(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text("ui_out_of_credits_body".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("ui_cancel".tr(),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PaywallScreen()));
            },
            child: Text("ui_go_to_store".tr()),
          )
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
      _showModeSelectionDialog();
    }
  }

  Future<void> _showModeSelectionDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10)),
              ),
              Text(
                'ui_select_analysis_type'.tr(),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'ui_select_model_desc'.tr(),
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 32),
              _buildSelectionCard(
                title: 'ui_chest'.tr(),
                subtitle: 'ui_chest_desc'.tr(),
                icon: Icons.personal_video_outlined,
                onTap: () {
                  Navigator.pop(context);
                  _apiService.warmUpServer();
                  _analyze('chest');
                },
              ),
              const SizedBox(height: 16),
              _buildSelectionCard(
                title: 'ui_bone'.tr(),
                subtitle: 'ui_bone_desc'.tr(),
                icon: Icons.animation,
                onTap: () {
                  Navigator.pop(context);
                  _apiService.warmUpServer();
                  _analyze('bone');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87, size: 28),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _analyze(String mode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final isDeveloper = user.email == _developerEmail;

    if (!isDeveloper) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final currentCredits = doc.data()?['credits'] ?? 0;

      if (currentCredits <= 0) {
        _showOutOfCreditsDialog();
        return;
      }
    }

    // 1. Grab the current device language code
    final String currentLang = context.locale.languageCode;

    setState(() {
      _isLoading = true;
      _results = null;
    });

    final response =
        await _apiService.uploadXray(_selectedImage!, mode, currentLang);

    if (response['success'] == true) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/scans/$fileName');
        await storageRef.putFile(_selectedImage!);
        final downloadUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('scans')
            .add({
          'date': DateFormat('d MMMM yyyy\nHH:mm').format(DateTime.now()),
          'timestamp': FieldValue.serverTimestamp(),
          'imageUrl': downloadUrl,
          'mode': mode,
          'report': response['report'],
          'heatmap': response['heatmap'],
          'ai_message': response['ai_message'],
        });

        if (!isDeveloper) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'credits': FieldValue.increment(-1)});
        }
      } catch (e) {
        print("Firebase Error: $e");
      }
    }

    setState(() {
      _isLoading = false;
      _results = response;
    });

    if (response['success'] == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Error: ${response['error'] ?? 'Unknown connection error'}"),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ---> NEW WHITEPAPER FUNCTIONS <---
  void _showModelsWhitepaper() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.architecture,
                      color: Colors.black87, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    "wp_title".tr(),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "wp_intro".tr(),
                        style: TextStyle(
                            fontSize: 15, height: 1.5, color: Colors.grey[800]),
                      ),
                      const SizedBox(height: 24),
                      _buildWhitepaperSection(
                          "wp_chest_title".tr(), "wp_chest_desc".tr()),
                      _buildWhitepaperSection(
                          "wp_bone_title".tr(), "wp_bone_desc".tr()),
                      _buildWhitepaperSection(
                          "wp_method_title".tr(), "wp_method_desc".tr()),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text("wp_close".tr(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWhitepaperSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style:
                TextStyle(fontSize: 14.5, height: 1.6, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializingProfile) {
      return const Center(
        child: SpinKitDoubleBounce(
            color: Color.fromARGB(255, 59, 59, 59), size: 60.0),
      );
    }

    if (_isLoading) {
      return const ModernLoadingScreen();
    }

    if (_results != null && _results!['success'] == true) {
      return ResultView(
        imageFile: _selectedImage!,
        resultData: {
          'report': _results!['report'],
          'mode': _results!['type'] == 'Bone Analysis' ? 'bone' : 'chest',
          'heatmap': _results!['heatmap'],
          'ai_message': _results!['ai_message'],
        },
        onBackPressed: () => setState(() {
          _results = null;
          _selectedImage = null;
        }),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int credits = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          credits = snapshot.data!.get('credits') ?? 0;
        }

        final isDeveloper = user?.email == _developerEmail;

        return SafeArea(
          child: Column(
            children: [
              // --- TOP NAVIGATION ROW ---
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Learn About Models Button
                    GestureDetector(
                      onTap: _showModelsWhitepaper,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_rounded,
                                color: Colors.black87, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "ui_learn_models".tr(),
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Credits Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              isDeveloper
                                  ? Icons.verified_user_rounded
                                  : Icons.offline_bolt_outlined,
                              color: Colors.black87,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isDeveloper
                                ? "ui_unlimited_credits".tr()
                                : "${'ui_credits'.tr()} $credits",
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- CENTER CIRCULAR UPLOAD BUTTON ---
              Expanded(
                child: Center(
                  child: GestureDetector(
                    // 1. Animation Triggers
                    onTapDown: (_) => setState(() => _isPressed = true),
                    onTapCancel: () => setState(() => _isPressed = false),
                    onTapUp: (_) {
                      setState(() => _isPressed = false);
                      _pickImage(); // Fire the actual upload function
                    },
                    // 2. The Smooth Scale Effect
                    child: AnimatedScale(
                      scale: _isPressed ? 0.94 : 1.0, // Shrinks to 94% on press
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        height: 240,
                        width: 240,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: const Color(0xFFE5EDF8).withOpacity(0.5),
                              blurRadius: 40,
                              spreadRadius: -10,
                              offset: const Offset(0, 0),
                            ),
                          ],
                          border:
                              Border.all(color: Colors.grey.shade100, width: 2),
                        ),
                        // 3. Icon removed, Text perfectly centered
                        child: Center(
                          child: Text(
                            "ui_tap_to_analyze".tr(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(
                                    0xFF2B5C9A), // Matches the AI box blue
                                fontSize: 22,
                                letterSpacing: -0.5,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 60), // Bottom padding balance
            ],
          ),
        );
      },
    );
  }
}

String translateMedicalTerm(String? englishTerm) {
  if (englishTerm == null) return "unknown_error".tr();
  String cleanedTerm = englishTerm.replaceAll(' ', '_').trim();
  return "model_$cleanedTerm".tr();
}
