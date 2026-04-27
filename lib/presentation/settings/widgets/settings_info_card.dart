import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../shared/utils.dart';
import '../../kviz_theme.dart';
import 'settings_detail_line.dart';

class SettingsInfoCard extends StatefulWidget {
  const SettingsInfoCard({
    super.key,
    required this.useCyrillic,
    required this.deviceId,
    required this.appVersion,
  });

  final bool useCyrillic;
  final String deviceId;
  final String appVersion;

  @override
  State<SettingsInfoCard> createState() => _SettingsInfoCardState();
}

class _SettingsInfoCardState extends State<SettingsInfoCard> {
  late final Future<PackageInfo> _packageInfoFuture;

  String t(String latin, String cyr) => tr(widget.useCyrillic, latin, cyr);

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final shortDevice = widget.deviceId.length <= 18
        ? widget.deviceId
        : '${widget.deviceId.substring(0, 18)}...';

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.info_outline_rounded, color: context.accentText),
          title: Text(
            t('Detalji aplikacije', 'Детаљи апликације'),
            style: TextStyle(
              color: context.strongText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          iconColor: context.accentText,
          collapsedIconColor: context.mutedText,
          children: [
            FutureBuilder<PackageInfo>(
              future: _packageInfoFuture,
              builder: (context, snapshot) {
                final packageInfo = snapshot.data;
                return Column(
                  children: [
                    SettingsDetailLine(
                      label: t('Verzija', 'Верзија'),
                      value: packageInfo?.version ?? widget.appVersion,
                    ),
                    SettingsDetailLine(
                      label: t('Broj', 'Број'),
                      value: packageInfo?.buildNumber ?? '-',
                    ),
                  ],
                );
              },
            ),
            SettingsDetailLine(
              label: t('Uređaj', 'Уређај'),
              value: shortDevice,
            ),
          ],
        ),
      ),
    );
  }
}
