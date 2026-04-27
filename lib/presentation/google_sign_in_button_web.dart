import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import 'google_sign_in_button_stub.dart' show GoogleSignInPressed;

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
    if (inProgress) {
      return KvizGoogleSignInButtonStub(progressLabel: progressLabel);
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(180.0, 400.0);
          return Align(
            alignment: Alignment.center,
            child: web.renderButton(
              configuration: web.GSIButtonConfiguration(
                type: web.GSIButtonType.standard,
                theme: web.GSIButtonTheme.filledBlue,
                size: web.GSIButtonSize.large,
                text: web.GSIButtonText.continueWith,
                shape: web.GSIButtonShape.rectangular,
                minimumWidth: width,
                locale: 'sr',
              ),
            ),
          );
        },
      ),
    );
  }
}

class KvizGoogleSignInButtonStub extends StatelessWidget {
  const KvizGoogleSignInButtonStub({super.key, required this.progressLabel});

  final String progressLabel;

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
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        label: Text(
          progressLabel,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
