import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
