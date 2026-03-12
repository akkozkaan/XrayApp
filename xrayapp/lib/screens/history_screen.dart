import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'analyze_screen.dart'; // To reuse ResultView
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_storage/firebase_storage.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return Center(child: Text("ui_login_required".tr()));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('scans')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SpinKitRipple(
              color: Colors.black87, // Neutral color
              size: 60.0,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text("ui_error_occurred".tr()));
        }

        final historyDocs = snapshot.data?.docs ?? [];

        if (historyDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  "ui_no_history".tr(),
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "ui_scan_history".tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85, // Slightly taller for modern look
                  ),
                  itemCount: historyDocs.length,
                  itemBuilder: (context, index) {
                    final String docId =
                        historyDocs[index].id; // <--- Grab the document ID
                    final item =
                        historyDocs[index].data() as Map<String, dynamic>;
                    final String imageUrl = item['imageUrl'] ?? '';
                    final bool hasHeatmap = item['heatmap'] != null;
                    final String mode = item['mode'] ?? 'chest';
                    // Parse the date if it exists, otherwise provide a fallback
                    final String rawDate = item['date'] ?? 'Unknown Date';
                    final String displayDate =
                        rawDate.split('\n').first; // Just grab the top line

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              backgroundColor: Colors.white,
                              body: SafeArea(
                                child: ResultView(
                                  imageUrl: imageUrl,
                                  resultData: item,
                                  onBackPressed: () => Navigator.pop(context),
                                  onDelete: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        title: Text("ui_delete_title".tr(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        content: Text("ui_delete_desc".tr()),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text("ui_cancel".tr(),
                                                style: const TextStyle(
                                                    color: Colors.grey)),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text("ui_delete".tr(),
                                                style: const TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 0, 0, 0),
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      final user =
                                          FirebaseAuth.instance.currentUser;
                                      if (user != null) {
                                        // 1. Delete from Firestore
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .collection('scans')
                                            .doc(docId)
                                            .delete();

                                        // 2. Delete from Storage
                                        if (imageUrl.isNotEmpty) {
                                          try {
                                            await FirebaseStorage.instance
                                                .refFromURL(imageUrl)
                                                .delete();
                                          } catch (e) {
                                            print(
                                                "Storage item already deleted or missing: $e");
                                          }
                                        }
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFEEEEEE), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- THE IMAGE ---
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(14)),
                                child: Image.network(
                                  imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: SpinKitDoubleBounce(
                                        color: Colors.grey.shade200,
                                        size: 30,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            // --- THE METADATA FOOTER ---
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        mode == 'bone' ? 'BONE' : 'CHEST',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (hasHeatmap)
                                        const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 14,
                                          color: Colors.black54,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayDate,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
