part of '../online_session_page.dart';

extension _OnlineSessionResultWidgets on _OnlineSessionPageState {
  Widget _buildFeedbackBanner() {
    final scheme = Theme.of(context).colorScheme;
    final isAssociation = _currentRound?.isAssociation == true;
    final isMyNumber = _currentRound?.isMyNumber == true;
    final targetPrefix = (_lastAssociationTargetLabel?.isNotEmpty ?? false)
        ? '${associationLabel(_lastAssociationTargetLabel!)}: '
        : '';
    final correctAnswer = s(_lastCorrectAnswer);
    final wrongText =
        !_lastCorrect &&
            !isAssociation &&
            (_lastCorrectAnswer?.isNotEmpty ?? false)
        ? t(
            '${targetPrefix}Netačno. Tačan odgovor je: $correctAnswer',
            '$targetPrefixНетачно. Тачан одговор је: $correctAnswer',
          )
        : t('${targetPrefix}Pogrešno', '$targetPrefixПогрешно');

    final mainText = _lastCorrect
        ? t(
            '${targetPrefix}Tačno! +$_lastPoints poena',
            '$targetPrefixТачно! +$_lastPoints поена',
          )
        : wrongText;

    final expressionLine = isMyNumber && _lastMyNumberExpression != null
        ? (_lastMyNumberValue != null
              ? '$_lastMyNumberExpression = $_lastMyNumberValue'
              : _lastMyNumberExpression!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _lastCorrect ? context.successBg : scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _lastCorrect ? context.successColor : scheme.error,
        ),
      ),
      child: Row(
        crossAxisAlignment: expressionLine != null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: expressionLine != null
                ? const EdgeInsets.only(top: 2)
                : EdgeInsets.zero,
            child: Icon(
              _lastCorrect ? Icons.emoji_events_rounded : Icons.close_rounded,
              color: _lastCorrect
                  ? const Color(0xFFFFD54F)
                  : const Color(0xFFEF5350),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mainText,
                  style: TextStyle(
                    color: _lastCorrect
                        ? context.successColor
                        : scheme.onErrorContainer,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (expressionLine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    expressionLine,
                    style: TextStyle(
                      color: _lastCorrect
                          ? context.successColor.withValues(alpha: 0.85)
                          : scheme.onErrorContainer.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            color: context.accentText,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 12),
          Text(
            _waitingMessage(),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: scheme.onErrorContainer,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.actionBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.actionBlue),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: context.actionBlue,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEndCard() {
    final isBlocked = _inputState == _InputState.blocked;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isBlocked ? const Color(0xFFEF5350) : const Color(0xFF4CAF50),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBlocked ? Icons.gpp_bad_rounded : Icons.emoji_events_rounded,
                color: isBlocked
                    ? const Color(0xFFEF5350)
                    : context.successColor,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBlocked
                          ? t('Partija prekinuta', 'Партија прекинута')
                          : (t('Partija završena!', 'Партија завршена!')),
                      style: TextStyle(
                        color: isBlocked
                            ? const Color(0xFFEF5350)
                            : context.accentText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_ratingDelta != null) ...[
                      Text(
                        t(
                          _ratingDelta! > 0
                              ? 'Dobitak rejtinga: +$_ratingDelta'
                              : 'Gubitak rejtinga: $_ratingDelta',
                          _ratingDelta! > 0
                              ? 'Добитак рејтинга: +$_ratingDelta'
                              : 'Губитак рејтинга: $_ratingDelta',
                        ),
                        style: TextStyle(
                          color: _ratingDelta! > 0
                              ? context.successColor
                              : context.errorColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_blockMessage != null) ...[
            Text(
              _blockMessage!,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_finishNote != null) ...[
            Text(
              _finishNote!,
              style: TextStyle(
                color: context.successColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_tieBreakerNote != null) ...[_buildInfoBanner(_tieBreakerNote!)],
          if (_unlockedAchievementLabels.isNotEmpty) ...[
            _buildInfoBanner(
              t(
                'Novo dostignuće: ${_unlockedAchievementLabels.map(s).join(', ')}',
                'Ново достигнуће: ${_unlockedAchievementLabels.map(s).join(', ')}',
              ),
            ),
          ],
          _buildContentReportReviewCard(),
          if (_contentReportDrafts.isNotEmpty) const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.innerBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFD54F),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '${t('Ukupan skor', 'Укупан скор')}: $_score',
                  style: TextStyle(
                    color: context.strongText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.actionBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(
                t('Nazad', 'Назад'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
