part of '../online_session_page.dart';

extension _OnlineSessionAnswerWidgets on _OnlineSessionPageState {
  Widget _buildAnswerInput(OnlineRound round) {
    final isSubmitting = _inputState == _InputState.submitting;
    final isAnswered = _inputState == _InputState.answered;
    final disabled = isSubmitting || isAnswered || _sessionStatus != 'active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _answerCtrl,
          enabled: !disabled,
          keyboardType: round.isMyNumber
              ? TextInputType.number
              : TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            color: context.strongText,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: round.isAssociation
                ? t(
                    'Upiši rešenje asocijacije...',
                    'Упиши решење асоцијације...',
                  )
                : round.isMyNumber
                ? t('Upiši dobijeni broj...', 'Упиши добијени број...')
                : t('Upiši odgovor...', 'Упиши одговор...'),
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
          onSubmitted: (_) => _submitAnswer(),
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
            onPressed: disabled ? null : _submitAnswer,
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
                    t('Potvrdi odgovor', 'Потврди одговор'),
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

  Widget _buildChoiceGrid(List<OnlineChoice> choices) {
    final isSubmitting = _inputState == _InputState.submitting;
    final isAnswered = _inputState == _InputState.answered;
    final disabled = isSubmitting || isAnswered || _sessionStatus != 'active';

    return Column(
      children: choices.map((choice) {
        final selected = _selectedChoiceText == choice.text;
        final showResult = selected && isAnswered;
        final borderColor = showResult
            ? (_lastCorrect ? const Color(0xFF4CAF50) : const Color(0xFFEF5350))
            : selected
            ? context.accentText
            : context.borderColor;
        final backgroundColor = showResult
            ? (_lastCorrect
                  ? context.successBg
                  : Theme.of(context).colorScheme.errorContainer)
            : selected
            ? context.innerBg
            : context.cardBg;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: disabled ? null : () => _submitChoice(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? context.actionBlue : context.innerBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        s(choice.label),
                        style: TextStyle(
                          color: selected ? Colors.white : context.strongText,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s(choice.text),
                        style: TextStyle(
                          color: context.strongText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (isSubmitting && selected)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.accentText,
                        ),
                      )
                    else if (showResult)
                      Icon(
                        _lastCorrect
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: _lastCorrect
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFEF5350),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
