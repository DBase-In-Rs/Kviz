import 'package:flutter/material.dart';
import '../../kviz_theme.dart';
import 'settings_panel.dart';
import 'settings_choice_grid.dart';
import 'settings_choice_tile.dart';

const settingsScriptModeSystem = 'system';
const settingsScriptModeLatin = 'latin';
const settingsScriptModeCyrillic = 'cyrillic';
const settingsTextSizeModeSystem = 'system';
const settingsTextSizeModeNormal = 'normal';
const settingsTextSizeModeLarge = 'large';

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.useCyrillic,
    required this.themeMode,
    required this.scriptMode,
    required this.textSizeMode,
    required this.largeText,
    required this.onThemeModeChanged,
    required this.onScriptModeChanged,
    required this.onTextSizeModeChanged,
  });

  final bool useCyrillic;
  final ThemeMode themeMode;
  final String scriptMode;
  final String textSizeMode;
  final bool largeText;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<String> onScriptModeChanged;
  final ValueChanged<String> onTextSizeModeChanged;

  @override
  Widget build(BuildContext context) {
    final previewText = useCyrillic
        ? 'Овако ће изгледати текст у игри.'
        : 'Ovako će izgledati tekst u igri.';
    final previewLabel = useCyrillic ? 'Пример приказа' : 'Primer prikaza';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsPanel(
          icon: Icons.palette_rounded,
          title: useCyrillic ? 'Приказ' : 'Prikaz',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsChoiceGrid(
                children: [
                  SettingsChoiceTile(
                    selected: themeMode == ThemeMode.system,
                    icon: Icons.brightness_auto_rounded,
                    label: useCyrillic ? 'Ауто' : 'Auto',
                    onTap: () => onThemeModeChanged(ThemeMode.system),
                  ),
                  SettingsChoiceTile(
                    selected: themeMode == ThemeMode.light,
                    icon: Icons.light_mode_rounded,
                    label: useCyrillic ? 'Светла' : 'Svetla',
                    onTap: () => onThemeModeChanged(ThemeMode.light),
                  ),
                  SettingsChoiceTile(
                    selected: themeMode == ThemeMode.dark,
                    icon: Icons.dark_mode_rounded,
                    label: useCyrillic ? 'Тамна' : 'Tamna',
                    onTap: () => onThemeModeChanged(ThemeMode.dark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SettingsChoiceGrid(
                children: [
                  SettingsChoiceTile(
                    selected: textSizeMode == settingsTextSizeModeSystem,
                    icon: Icons.text_fields_rounded,
                    label: useCyrillic ? 'Текст ауто' : 'Tekst auto',
                    onTap: () =>
                        onTextSizeModeChanged(settingsTextSizeModeSystem),
                  ),
                  SettingsChoiceTile(
                    selected: textSizeMode == settingsTextSizeModeNormal,
                    icon: Icons.text_fields_rounded,
                    label: useCyrillic ? 'Нормалан' : 'Normalan',
                    onTap: () =>
                        onTextSizeModeChanged(settingsTextSizeModeNormal),
                  ),
                  SettingsChoiceTile(
                    selected: textSizeMode == settingsTextSizeModeLarge,
                    icon: Icons.text_increase_rounded,
                    label: useCyrillic ? 'Већи' : 'Veći',
                    onTap: () =>
                        onTextSizeModeChanged(settingsTextSizeModeLarge),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.innerBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewLabel,
                      style: TextStyle(
                        color: context.accentText,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      previewText,
                      style: TextStyle(
                        color: context.strongText,
                        fontSize: largeText ? 18 : 15,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsPanel(
          icon: Icons.translate_rounded,
          title: useCyrillic ? 'Писмо' : 'Pismo',
          child: SettingsChoiceGrid(
            children: [
              SettingsChoiceTile(
                selected: scriptMode == settingsScriptModeSystem,
                icon: Icons.language_rounded,
                label: useCyrillic ? 'Ауто' : 'Auto',
                onTap: () => onScriptModeChanged(settingsScriptModeSystem),
              ),
              SettingsChoiceTile(
                selected: scriptMode == settingsScriptModeLatin,
                icon: Icons.language_rounded,
                label: 'Latinica',
                onTap: () => onScriptModeChanged(settingsScriptModeLatin),
              ),
              SettingsChoiceTile(
                selected: scriptMode == settingsScriptModeCyrillic,
                icon: Icons.translate_rounded,
                label: 'Ћирилица',
                onTap: () => onScriptModeChanged(settingsScriptModeCyrillic),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
