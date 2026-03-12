import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart'; // <--- 1. Import translator

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  Future<void> _fetchOffers() async {
    try {
      final offerings = await Purchases.getOfferings();
      setState(() {
        _offerings = offerings;
        _isLoading = false;
      });
    } catch (e) {
      print("RevenueCat Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _buyPackage(Package package) async {
    setState(() => _isPurchasing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null)
        throw Exception("ui_error_not_logged_in".tr()); // <--- TRANSLATED

      // 1. Tell RevenueCat exactly which Firebase User is making this purchase
      await Purchases.logIn(user.uid);

      // 2. Trigger the Google Play payment sheet
      final customerInfo = await Purchases.purchasePackage(package);

      // 3. FORCE THE DATABASE UPDATE
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'credits': FieldValue.increment(10)});

      // 4. Show success and close paywall
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              // Removed const
              content: Text("ui_payment_success".tr()), // <--- TRANSLATED
              backgroundColor: const Color.fromARGB(255, 0, 0, 0)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text("ui_purchase_detail".tr()), // <--- TRANSLATED
                  content: Text(e.toString()),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("ui_ok".tr(), // <--- TRANSLATED
                            style: const TextStyle(
                                color: Color.fromARGB(255, 2, 28, 229))))
                  ],
                ));
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade50, // Slightly off-white background for depth
      appBar: AppBar(
        title: Text(
            "ui_store_title".tr(), // <--- TRANSLATED (Reused existing key)
            style: const TextStyle(
                fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 0, 0, 0)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- PLAIN & COOL HEADER ICON ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 44, 44, 44)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.offline_bolt_outlined,
                        size: 70, color: Color.fromARGB(255, 44, 44, 44)),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    "ui_out_of_credits_header".tr(), // <--- TRANSLATED
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "ui_store_description".tr(), // <--- TRANSLATED
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade600,
                        height: 1.4),
                  ),
                  const SizedBox(height: 40),

                  // Show the RevenueCat Packages
                  if (_offerings != null &&
                      _offerings!.current != null &&
                      _offerings!.current!.availablePackages.isNotEmpty)
                    ..._offerings!.current!.availablePackages.map((package) {
                      // ---> THE MAGIC SNIP <---
                      final String cleanTitle =
                          package.storeProduct.title.split(' (').first.trim();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cleanTitle, // Already dynamic from Google Play
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "ui_10_xray_analysis"
                                        .tr(), // <--- TRANSLATED
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // --- THE NEW GLOWING BUTTON ---
                            _isPurchasing
                                ? const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 24),
                                    child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: Color.fromARGB(
                                                255, 16, 12, 216),
                                            strokeWidth: 3)),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color.fromARGB(255, 0, 0, 0),
                                          Color.fromARGB(255, 0, 0, 0)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => _buyPackage(package),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 12),
                                          child: Text(
                                            package.storeProduct
                                                .priceString, // Native currency, no translation needed!
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      );
                    })
                  else
                    Text(
                      "ui_store_unavailable".tr(), // <--- TRANSLATED
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
    );
  }
}
