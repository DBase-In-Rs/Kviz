import 'package:flutter/material.dart';

typedef GoogleSignInPressed = Future<void> Function();

class KvizGoogleSignInButton extends StatelessWidget {
  const KvizGoogleSignInButton({
    super.key,
    required this.inProgress,
    required this.label,
    required this.progressLabel,
    this.onPressed,
  });

  final bool inProgress;
  final String label;
  final String progressLabel;
  final GoogleSignInPressed? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4C86),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        icon: inProgress
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.login_rounded, size: 20),
        label: Text(
          inProgress ? progressLabel : label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
