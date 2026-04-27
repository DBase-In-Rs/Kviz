part of '../online_session_page.dart';

extension _OnlineSessionAssociationWidgets on _OnlineSessionPageState {
  Widget _buildAssociationGrid(OnlineRound round) {
    final grid = round.associationGrid;
    if (grid == null) {
      return Text(
        t('(grid se učitava...)', '(grid се учитава...)'),
        style: TextStyle(color: context.mutedText),
      );
    }
    final columns = [
      MapEntry('A', grid['a'] ?? []),
      MapEntry('B', grid['b'] ?? []),
      MapEntry('V', grid['v'] ?? []),
      MapEntry('G', grid['g'] ?? []),
    ];
    final finalResult = _buildAssociationResultLine('final', isFinal: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: columns.map((entry) {
            final targetKey = entry.key.toLowerCase();
            final resultLine = _buildAssociationResultLine(targetKey);
            final owner = _associationTargetOwners[targetKey];
            final solvedBySelf = owner == 'self';
            final solvedByOpponent = owner == 'opponent';
            final columnColor = solvedBySelf
                ? context.actionBlue.withValues(alpha: 0.10)
                : solvedByOpponent
                ? const Color(0xFFEF5350).withValues(alpha: 0.12)
                : context.innerBg;
            final columnBorder = solvedBySelf
                ? context.actionBlue
                : solvedByOpponent
                ? const Color(0xFFEF5350)
                : context.borderColor;

            return Container(
              width: 148,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: columnColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: columnBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t('Kolona', 'Колона')} ${associationLabel(entry.key)}',
                    style: TextStyle(
                      color: context.accentText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...entry.value.map(
                    (clue) => Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        s(clue),
                        style: TextStyle(
                          color: context.strongText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ?resultLine,
                ],
              ),
            );
          }).toList(),
        ),
        if (finalResult != null) ...[const SizedBox(height: 8), finalResult],
      ],
    );
  }

  Widget? _buildAssociationResultLine(
    String targetKey, {
    bool isFinal = false,
  }) {
    final wasSolved =
        _associationTargetCorrect[targetKey] == true ||
        _associationTargetSolutions.containsKey(targetKey);
    if (!wasSolved) return null;

    final solution = _associationTargetSolutions[targetKey];
    final owner = _associationTargetOwners[targetKey];
    final solvedBySelf = owner == 'self';
    final solvedByOpponent = owner == 'opponent';
    final bgColor = solvedBySelf
        ? context.actionBlue.withValues(alpha: 0.12)
        : solvedByOpponent
        ? const Color(0xFFEF5350).withValues(alpha: 0.14)
        : context.innerBg;
    final borderColor = solvedBySelf
        ? context.actionBlue
        : solvedByOpponent
        ? const Color(0xFFEF5350)
        : context.borderColor;
    final textColor = solvedBySelf
        ? context.actionBlue
        : solvedByOpponent
        ? const Color(0xFFEF5350)
        : context.strongText;
    final label = isFinal
        ? t('Konačno', 'Коначно')
        : associationLabel(targetKey);
    final prefix = solvedByOpponent
        ? t('Protivnik', 'Противник')
        : solvedBySelf
        ? t('Pogođeno', 'Погођено')
        : t('Rešenje', 'Решење');
    final text = solution == null || solution.isEmpty
        ? '$label: $prefix'
        : '$label: $prefix - ${s(solution)}';

    return Container(
      margin: EdgeInsets.only(top: isFinal ? 0 : 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: isFinal ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(
            solvedByOpponent ? Icons.lock_rounded : Icons.check_circle_rounded,
            color: textColor,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssociationAnswerInput(OnlineRound round) {
    final isSubmitting = _inputState == _InputState.submitting;
    final isAnswered = _inputState == _InputState.answered;
    final disabled =
        isSubmitting ||
        isAnswered ||
        _associationRoundResolved ||
        _sessionStatus != 'active';
    final activeTarget = _activeAssociationTarget(round);
    final activeLabel = _associationTargetLabel(round, activeTarget);
    final activeAnswered = _answeredAssociationTargets.contains(activeTarget);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: round.associationTargets.map((target) {
            final done = _answeredAssociationTargets.contains(target.key);
            final selected = activeTarget == target.key;
            final owner = _associationTargetOwners[target.key];
            final solvedByOpponent = owner == 'opponent';
            final chipColor = selected
                ? context.actionBlue
                : done
                ? (solvedByOpponent
                      ? const Color(0xFFEF5350).withValues(alpha: 0.16)
                      : context.actionBlue.withValues(alpha: 0.14))
                : context.cardBg;
            final labelColor = selected
                ? Colors.white
                : done
                ? (solvedByOpponent
                      ? const Color(0xFFEF5350)
                      : context.actionBlue)
                : context.strongText;
            final doneBorderColor = solvedByOpponent
                ? const Color(0xFFEF5350)
                : context.actionBlue;

            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (done) ...[
                    Icon(
                      solvedByOpponent
                          ? Icons.lock_rounded
                          : Icons.check_circle_rounded,
                      color: labelColor,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    _associationTargetLabel(round, target.key),
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              selected: selected,
              showCheckmark: false,
              selectedColor: chipColor,
              backgroundColor: chipColor,
              disabledColor: chipColor,
              side: BorderSide(
                color: selected
                    ? context.actionBlue
                    : done
                    ? doneBorderColor
                    : context.borderColor,
              ),
              onSelected: disabled || done
                  ? null
                  : (_) {
                      _updateState(() {
                        _associationTarget = target.key;
                        _blockMessage = null;
                        _associationNotice = null;
                      });
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _answerCtrl,
          enabled: !disabled && !activeAnswered,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            color: context.strongText,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: activeTarget == 'final'
                ? t('Upiši konačno rešenje...', 'Упиши коначно решење...')
                : t(
                    'Upiši rešenje za polje $activeLabel...',
                    'Упиши решење за поље $activeLabel...',
                  ),
            hintStyle: TextStyle(color: context.mutedText),
            filled: true,
            fillColor: context.cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.accentText, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onSubmitted: (_) {
            if (!activeAnswered) _submitAnswer();
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.actionBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: disabled || activeAnswered ? null : _submitAnswer,
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    activeTarget == 'final'
                        ? t('Potvrdi konačno', 'Потврди коначно')
                        : t(
                            'Potvrdi polje $activeLabel',
                            'Потврди поље $activeLabel',
                          ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
