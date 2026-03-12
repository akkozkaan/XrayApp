import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // <--- 1. Required for clickable text
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  late TapGestureRecognizer
      _termsRecognizer; // <--- 2. Gesture recognizer for the link

  @override
  void initState() {
    super.initState();
    // Initialize the clickable text recognizer
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        _showTermsDialog(context);
      };
  }

  @override
  void dispose() {
    // Clean up the recognizer when screen is destroyed
    _termsRecognizer.dispose();
    super.dispose();
  }

  // ---> 3. THE GENERATED MEDICAL AI TERMS & CONDITIONS <---
  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Color.fromARGB(255, 0, 0, 0)),
            SizedBox(width: 10),
            Text("Terms & Conditions",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            """Welcome to Fjyn. By using our application, you agree to the following terms:

1. Educational & Informational Use Only
Fjyn utilizes artificial intelligence to analyze X-ray imagery. The results, heatmaps (Grad-CAM), and predictions provided by this application are strictly for informational and educational purposes. Fjyn is NOT a diagnostic medical device and must NEVER replace professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider.

2. User Responsibilities
You represent and warrant that you have the legal right and necessary consents to upload any medical imaging data into the application. Please ensure that uploaded images do not contain visible Protected Health Information (PHI) such as patient names or ID numbers.

3. AI Limitations
While our models are trained on extensive datasets, artificial intelligence is probabilistic and subject to limitations, false positives, and false negatives. We explicitly disclaim any liability for decisions made based on the app's output.

4. Data Privacy
Images are processed securely to generate your analysis. Your scan history is stored in your personal account to provide you with historical access. We do not sell your personal data to third parties.

5. Limitation of Liability
Under no circumstances shall the developers of Fjyn be liable for any direct, indirect, incidental, or consequential damages arising from your use of the application or reliance on its analysis.

By proceeding, you acknowledge that you have read, understood, and agreed to these terms.""",
            style: TextStyle(
                fontSize: 14, color: Colors.grey.shade800, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("I Understand",
                style: TextStyle(
                    color: Color.fromARGB(255, 0, 0, 0),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId:
            '77515269830-o7pa9k2880tf8s10lo2rps639c9co9p0.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print("Kullanıcı girişi iptal etti.");
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        await Purchases.logIn(userCredential.user!.uid);
      }
    } catch (e) {
      print("Giriş iptal edildi veya hata oluştu: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showReviewerLoginDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoggingIn = false;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text("Reviewer Login",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 19, 12, 208),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoggingIn
                      ? null
                      : () async {
                          setDialogState(() => isLoggingIn = true);
                          try {
                            final userCredential = await FirebaseAuth.instance
                                .signInWithEmailAndPassword(
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                            );

                            if (userCredential.user != null) {
                              await Purchases.logIn(userCredential.user!.uid);
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text("Login failed: $e"),
                                    backgroundColor: Colors.red),
                              );
                            }
                            setDialogState(() => isLoggingIn = false);
                          }
                        },
                  child: isLoggingIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Login"),
                )
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ---> 1. YOUR NEW LOGO <---
              Image.asset(
                'assets/logo.png', // Make sure this matches your file name exactly!
                height: 160, // Adjust this number to make it bigger or smaller
              ),
              const SizedBox(
                  height: 16), // Breathing room between the logo and the text

              // ---> 2. THE MEZU TITLE <---
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 0, 0, 0),
                    Color.fromARGB(255, 0, 0, 0)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Text(
                  'Fjyn',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "ui_app_subtitle".tr(),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),

              _isLoading
                  ? const CircularProgressIndicator(
                      color: Color.fromARGB(255, 0, 0, 0))
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        elevation: 0,
                      ),
                      onPressed: signInWithGoogle,
                      icon: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                        height: 24,
                      ),
                      label: Text(
                        "ui_login_google".tr(),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2),
                      ),
                    ),

              const SizedBox(height: 20), // Spacing below login button

              // ---> 4. THE CLICKABLE TERMS TEXT <---
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13, height: 1.4),
                  children: [
                    const TextSpan(text: "By signing in, you accept our\n"),
                    TextSpan(
                      text: "Terms and Conditions",
                      style: const TextStyle(
                        color: Color.fromARGB(255, 24, 24, 24),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer:
                          _termsRecognizer, // Connects the click to the dialog!
                    ),
                    const TextSpan(text: "."),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              TextButton(
                onPressed: () => _showReviewerLoginDialog(context),
                child: const Text(
                  "Developer / Reviewer Login",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
