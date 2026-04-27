part of '../online_session_page.dart';

class _FooterStat extends StatelessWidget {
  const _FooterStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.valueColor,
    required this.labelColor,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 27),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: color,
    );
  }
}
