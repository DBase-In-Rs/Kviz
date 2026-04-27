import 'package:flutter/material.dart';

class SettingsChoiceGrid extends StatelessWidget {
  const SettingsChoiceGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 520;
        final width = twoColumns
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}
