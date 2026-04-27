import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:upgrader/upgrader.dart';

import '../data/remote/analytics_service.dart';
import '../shared/utils.dart';
import 'kviz_theme.dart';

class KvizUpdateNoticeBanner extends StatefulWidget {
  const KvizUpdateNoticeBanner({super.key, required this.useCyrillic});

  final bool useCyrillic;

  @override
  State<KvizUpdateNoticeBanner> createState() => _KvizUpdateNoticeBannerState();
}

class _KvizUpdateNoticeBannerState extends State<KvizUpdateNoticeBanner> {
  late Upgrader _upgrader;
  AppUpdateInfo? _playUpdateInfo;
  bool _checkingPlayUpdate = false;
  bool _startingPlayUpdate = false;

  @override
  void initState() {
    super.initState();
    _upgrader = _createUpgrader();
    _checkPlayUpdate();
  }

  @override
  void didUpdateWidget(covariant KvizUpdateNoticeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useCyrillic != widget.useCyrillic) {
      _upgrader.dispose();
      _upgrader = _createUpgrader();
    }
  }

  @override
  void dispose() {
    _upgrader.dispose();
    super.dispose();
  }

  Upgrader _createUpgrader() {
    return Upgrader(
      countryCode: 'RS',
      languageCode: 'sr',
      messages: _KvizUpgraderMessages(useCyrillic: widget.useCyrillic),
    );
  }

  bool get _isAndroid {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  bool get _hasPlayUpdate {
    final info = _playUpdateInfo;
    if (info == null) {
      return false;
    }

    return info.updateAvailability == UpdateAvailability.updateAvailable ||
        info.updateAvailability ==
            UpdateAvailability.developerTriggeredUpdateInProgress ||
        info.installStatus == InstallStatus.downloaded;
  }

  Future<void> _checkPlayUpdate() async {
    if (!_isAndroid || _checkingPlayUpdate) {
      return;
    }

    setState(() => _checkingPlayUpdate = true);
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (!mounted) return;
      setState(() => _playUpdateInfo = info);
      if (_hasPlayUpdate) {
        KvizAnalytics.event(
          'play_in_app_update_available',
          parameters: <String, Object?>{
            'available_version_code': info.availableVersionCode,
            'priority': info.updatePriority,
          },
        );
      }
    } catch (error) {
      KvizAnalytics.event(
        'play_in_app_update_check_failed',
        parameters: <String, Object?>{'reason': error.toString()},
      );
    } finally {
      if (mounted) {
        setState(() => _checkingPlayUpdate = false);
      }
    }
  }

  Future<void> _startPlayUpdate() async {
    final info = _playUpdateInfo;
    if (info == null || _startingPlayUpdate) {
      return;
    }

    KvizAnalytics.uiAction(
      screen: 'app_shell',
      area: 'update_notice',
      target: 'start_play_in_app_update',
      parameters: <String, Object?>{
        'available_version_code': info.availableVersionCode,
        'flexible_allowed': info.flexibleUpdateAllowed,
        'immediate_allowed': info.immediateUpdateAllowed,
      },
    );

    setState(() => _startingPlayUpdate = true);
    try {
      if (info.installStatus == InstallStatus.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }

      if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
        return;
      }

      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (error) {
      KvizAnalytics.event(
        'play_in_app_update_start_failed',
        parameters: <String, Object?>{'reason': error.toString()},
      );
    } finally {
      if (mounted) {
        setState(() => _startingPlayUpdate = false);
      }
    }
  }

  bool _trackOpenPlayStore() {
    KvizAnalytics.uiAction(
      screen: 'app_shell',
      area: 'update_notice',
      target: 'open_google_play',
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPlayUpdate) {
      return _buildPlayUpdateCard(context);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: UpgradeCard(
            key: ValueKey<bool>(widget.useCyrillic),
            upgrader: _upgrader,
            margin: EdgeInsets.zero,
            showIgnore: false,
            showLater: false,
            showPrompt: false,
            showReleaseNotes: false,
            onUpdate: _trackOpenPlayStore,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayUpdateCard(BuildContext context) {
    final info = _playUpdateInfo;
    final versionCode = info?.availableVersionCode?.toString();
    final subtitle = versionCode == null
        ? tr(
            widget.useCyrillic,
            'Nova verzija je dostupna na Google Play-u.',
            'Нова верзија је доступна на Google Play-у.',
          )
        : tr(
            widget.useCyrillic,
            'Nova verzija je dostupna na Google Play-u. Build $versionCode.',
            'Нова верзија је доступна на Google Play-у. Build $versionCode.',
          );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.warningBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.warningBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.system_update_rounded,
                      color: context.warningText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(
                          widget.useCyrillic,
                          'Dostupan je apdejt',
                          'Доступан је апдејт',
                        ),
                        style: TextStyle(
                          color: context.warningText,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.warningText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _startingPlayUpdate ? null : _startPlayUpdate,
                  icon: _startingPlayUpdate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    _startingPlayUpdate
                        ? tr(
                            widget.useCyrillic,
                            'Pokretanje...',
                            'Покретање...',
                          )
                        : tr(
                            widget.useCyrillic,
                            'Ažuriraj aplikaciju',
                            'Ажурирај апликацију',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KvizUpgraderMessages extends UpgraderMessages {
  _KvizUpgraderMessages({required this.useCyrillic}) : super(code: 'sr');

  final bool useCyrillic;

  String _text(String latin, String cyr) => tr(useCyrillic, latin, cyr);

  @override
  String get title => _text('Dostupan je apdejt', 'Доступан је апдејт');

  @override
  String get body => _text(
    'Dostupna je nova verzija aplikacije Kviz DBase na Google Play-u.',
    'Доступна је нова верзија апликације Kviz DBase на Google Play-у.',
  );

  @override
  String get buttonTitleUpdate =>
      _text('OTVORI GOOGLE PLAY', 'ОТВОРИ GOOGLE PLAY');

  @override
  String get buttonTitleIgnore => _text('SAKRIJ', 'САКРИЈ');

  @override
  String get buttonTitleLater => _text('KASNIJE', 'КАСНИЈЕ');

  @override
  String get prompt => _text(
    'Ažuriraj aplikaciju da koristiš najnoviju verziju.',
    'Ажурирај апликацију да користиш најновију верзију.',
  );

  @override
  String get releaseNotes => _text('Šta je novo', 'Шта је ново');
}
