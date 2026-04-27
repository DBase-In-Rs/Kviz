part of '../online_session_page.dart';

extension _OnlineSessionMyNumberWidgets on _OnlineSessionPageState {
  Widget _buildMyNumberPayload(OnlineRound round) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${t('Traženi broj', 'Тражени број')}: ${round.target ?? '-'}',
          style: TextStyle(
            color: context.strongText,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        if ((round.prompt ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            s(round.prompt!),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMyNumberBuilder(OnlineRound round) {
    final isSubmitting = _inputState == _InputState.submitting;
    final isAnswered = _inputState == _InputState.answered;
    final disabled = isSubmitting || isAnswered || _sessionStatus != 'active';
    final expression = _myNumberExpression;
    final usedCounts = _usedMyNumberCounts();
    final availableCounts = <int, int>{};
    for (final number in round.numbers) {
      availableCounts[number] = (availableCounts[number] ?? 0) + 1;
    }

    MyNumberExpressionResult? result;
    var previewError = _myNumberError;
    if (expression.isNotEmpty) {
      try {
        result = MyNumberExpressionEvaluator.evaluate(
          expression,
          round.numbers,
        );
      } on MyNumberExpressionException {
        previewError ??= t(
          'Postupak još nije završen ili nije dozvoljen.',
          'Поступак још није завршен или није дозвољен.',
        );
      }
    }

    final target = round.target;
    final canSubmit = !disabled && result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: round.numbers.map((number) {
            final available = availableCounts[number] ?? 0;
            final used = usedCounts[number] ?? 0;
            final canUse = !disabled && used < available;

            return SizedBox(
              width: 58,
              height: 46,
              child: OutlinedButton(
                onPressed: canUse
                    ? () => _appendMyNumberToken('$number')
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: context.borderColor),
                  backgroundColor: canUse ? context.cardBg : context.innerBg,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: canUse ? context.strongText : context.mutedText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['+', '-', '*', '/', '(', ')'].map((token) {
            return SizedBox(
              width: 48,
              height: 42,
              child: OutlinedButton(
                onPressed: disabled ? null : () => _appendMyNumberToken(token),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: context.borderColor),
                ),
                child: Text(
                  token,
                  style: TextStyle(
                    color: context.accentText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.innerBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Text(
            expression.isEmpty
                ? t('Sastavi postupak...', 'Састави поступак...')
                : expression,
            style: TextStyle(
              color: expression.isEmpty
                  ? context.mutedText
                  : context.strongText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (result != null)
          Text(
            target == null
                ? '${t('Rezultat', 'Резултат')}: ${result.value}'
                : '${t('Rezultat', 'Резултат')}: ${result.value}  |  ${t('Razlika', 'Разлика')}: ${result.distanceTo(target)}',
            style: TextStyle(
              color: result.distanceTo(target ?? result.value) == 0
                  ? context.successColor
                  : context.accentText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          )
        else if (previewError != null)
          Text(
            previewError,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : _removeLastMyNumberToken,
                icon: const Icon(Icons.backspace_outlined),
                label: Text(t('Obriši', 'Обриши')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : _clearMyNumberExpression,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(t('Poništi', 'Поништи')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.actionBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: canSubmit
                ? () => _submitMyNumberExpression(round)
                : null,
            icon: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.calculate_rounded),
            label: Text(
              t('Potvrdi postupak', 'Потврди поступак'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
