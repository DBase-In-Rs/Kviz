part of '../online_session_page.dart';

extension _OnlineSessionCommonQuestionWidgets on _OnlineSessionPageState {
  Widget _buildSessionHeader() {
    final total = _rounds.length;
    final progress = total == 0 ? 0.0 : (_roundIdx + 1) / total;
    final round = _currentRound;
    final isBlocked =
        _inputState == _InputState.blocked ||
        _inputState == _InputState.finished;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isBlocked
                      ? t('Završeno', 'Завршено')
                      : '${t('Runda', 'Рунда')} ${_roundIdx + 1}/$total'
                            '${round != null ? ': ${_roundTypeLabel(round)}' : ''}',
                  style: TextStyle(
                    color: context.strongText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isBlocked)
                Text(
                  '${_timeLeft}s',
                  style: TextStyle(
                    color: _timeLeft <= 5
                        ? const Color(0xFFEF5350)
                        : context.accentText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.innerBg,
              color: context.accentText,
            ),
          ),
          if (widget.isDuel && _opponentProgress != null && !isBlocked) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _opponentRoundLabel(),
                    style: TextStyle(
                      color: context.dimText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _opponentProgress!['status'] == 'finished'
                      ? t('Završio', 'Завршио')
                      : t('Igra', 'Игра'),
                  style: TextStyle(
                    color: context.dimText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${t('Skor', 'Скор')}: $_score',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_inputState == _InputState.waiting)
                Text(
                  t('Čeka se sledeća runda...', 'Чека се следећа рунда...'),
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoundContent() {
    final round = _currentRound;
    if (round == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_blockMessage != null && _inputState != _InputState.blocked)
          _buildErrorBanner(_blockMessage!),
        if (_associationNotice != null && _inputState != _InputState.blocked)
          _buildInfoBanner(_associationNotice!),
        if (_inputState == _InputState.answered) _buildFeedbackBanner(),
        if (_inputState == _InputState.waiting)
          _buildWaitingCard()
        else
          _buildQuestionCard(round),
        const SizedBox(height: 14),
        _buildGameFooter(),
      ],
    );
  }

  Widget _buildQuestionCard(OnlineRound round) {
    final choices = round.isQuestion ? const <OnlineChoice>[] : round.choices;
    final qText =
        round.questionText ??
        round.prompt ??
        (round.isAssociation
            ? t('Asocijacija', 'Асоцијација')
            : t('(pitanje se učitava...)', '(питање се учитава...)'));
    final hintText = round.isQuestion ? _questionHintText(round) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: context.innerBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _roundTypeLabel(round),
                      style: TextStyle(
                        color: context.accentText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_canReportRound(round)) _buildReportButton(round),
                ],
              ),
              if (round.isAssociation)
                _buildAssociationGrid(round)
              else if (round.isMyNumber)
                _buildMyNumberPayload(round)
              else if (round.isTangram)
                _buildTangramPayload(round)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s(qText),
                      style: TextStyle(
                        color: context.strongText,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    if (hintText != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: context.accentText,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hintText,
                              style: TextStyle(
                                color: context.mutedText,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (round.isTangram)
          _buildTangramAction()
        else if (round.isMyNumber)
          _buildMyNumberBuilder(round)
        else if (round.isAssociation)
          _buildAssociationAnswerInput(round)
        else if (choices.isNotEmpty)
          _buildChoiceGrid(choices)
        else
          _buildAnswerInput(round),
      ],
    );
  }

  Widget _buildReportButton(OnlineRound round) {
    final hasDraft = _contentReportDrafts.containsKey(_reportKeyFor(round));

    return Tooltip(
      message: t('Prijavi problem', 'Пријави проблем'),
      child: TextButton.icon(
        onPressed: () => _openContentReportSheet(round),
        style: TextButton.styleFrom(
          foregroundColor: hasDraft ? context.successColor : context.errorColor,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(
          hasDraft ? Icons.flag : Icons.outlined_flag_rounded,
          size: 18,
        ),
        label: Text(
          hasDraft ? t('Prijavljeno', 'Пријављено') : t('Prijavi', 'Пријави'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildGameFooter() {
    final accuracy = _answeredCount == 0
        ? 0
        : ((_correctCount / _answeredCount) * 100).round();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isDark ? Colors.white : context.strongText;
    final labelColor = isDark ? const Color(0xFFE1EEF8) : context.mutedText;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : context.borderColor;
    final footerColors = isDark
        ? const [Color(0xFF061F3C), Color(0xFF073A69)]
        : <Color>[context.cardBg, context.innerBg];

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: footerColors,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _FooterStat(
                  icon: Icons.emoji_events_rounded,
                  iconColor: const Color(0xFFFFC928),
                  value: '$_score',
                  label: t('Poeni', 'Поени'),
                  valueColor: valueColor,
                  labelColor: labelColor,
                ),
              ),
              _FooterDivider(color: dividerColor),
              Expanded(
                child: _FooterStat(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFF28D96B),
                  value: '$_streak',
                  label: t('Niz', 'Низ'),
                  valueColor: valueColor,
                  labelColor: labelColor,
                ),
              ),
              _FooterDivider(color: dividerColor),
              Expanded(
                child: _FooterStat(
                  icon: Icons.track_changes_rounded,
                  iconColor: const Color(0xFFFF2A36),
                  value: '$accuracy%',
                  label: t('Tačnost', 'Тачност'),
                  valueColor: valueColor,
                  labelColor: labelColor,
                ),
              ),
              _FooterDivider(color: dividerColor),
              Expanded(
                child: _FooterStat(
                  icon: Icons.timer_rounded,
                  iconColor: const Color(0xFF61C8FF),
                  value: '00:${_timeLeft.toString().padLeft(2, '0')}',
                  label: t('Vreme', 'Време'),
                  valueColor: valueColor,
                  labelColor: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roundTypeLabel(OnlineRound round) {
    if (round.isAssociation) return t('Asocijacije', 'Асоцијације');
    if (round.isMyNumber) return t('Moj Broj', 'Мој Број');
    if (round.isTangram) return t('Tangram+', 'Танграм+');
    return t('Ko zna zna', 'Ко зна зна');
  }

  Widget _buildContentReportReviewCard() {
    if (_contentReportDrafts.isEmpty) {
      return const SizedBox.shrink();
    }

    final drafts = _contentReportDrafts.entries.toList(growable: false);
    final pendingCount = drafts.where((entry) => !entry.value.submitted).length;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.innerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: context.errorColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('Pregled prijava', 'Преглед пријава'),
                  style: TextStyle(
                    color: context.strongText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$pendingCount/${drafts.length}',
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...drafts.map((entry) {
            final draft = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s(_draftTitle(draft)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.strongText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (draft.submitted)
                        Icon(
                          Icons.check_circle_rounded,
                          color: context.successColor,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _reportReasonLabel(draft.reason),
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((draft.userComment ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      s(draft.userComment!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.dimText, fontSize: 13),
                    ),
                  ],
                  if (!draft.submitted) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _openContentReportDraftEditor(entry.key, draft),
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: Text(t('Izmeni', 'Измени')),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _updateState(() {
                              _contentReportDrafts.remove(entry.key);
                            });
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: Text(t('Ukloni', 'Уклони')),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
          if (_contentReportSubmitError != null) ...[
            Text(
              s(_contentReportSubmitError!),
              style: TextStyle(
                color: context.errorColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (pendingCount > 0)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _contentReportsSubmitting
                    ? null
                    : _submitContentReports,
                icon: _contentReportsSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _contentReportsSubmitting
                      ? t('Slanje...', 'Слање...')
                      : t('Pošalji prijave', 'Пошаљи пријаве'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
