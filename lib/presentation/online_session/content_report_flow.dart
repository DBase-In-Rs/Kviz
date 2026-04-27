part of '../online_session_page.dart';

extension _OnlineSessionContentReportFlow on _OnlineSessionPageState {
  bool _canReportRound(OnlineRound round) {
    return (round.isQuestion || round.isAssociation) &&
        round.questionId != null;
  }

  String? _associationTargetForReport(OnlineRound round) {
    if (!round.isAssociation) {
      return null;
    }

    final activeTarget = _associationTarget.trim();
    if (activeTarget.isEmpty) {
      return 'final';
    }

    return activeTarget;
  }

  String _contentTypeFor(OnlineRound round) {
    return round.isAssociation ? 'association' : 'question';
  }

  String _reportKeyFor(OnlineRound round) {
    final target = _associationTargetForReport(round) ?? 'question';
    return '${round.questionSource}:${round.questionId}:${round.roundKey}:$target';
  }

  String _newReportId(OnlineRound round) {
    final target = _associationTargetForReport(round) ?? 'question';
    return 'report_${widget.sessionId}_${round.roundKey}_${round.questionSource}_${round.questionId}_${target}_${_newEventId()}';
  }

  String _reportReasonLabel(String reason) {
    return switch (reason) {
      'wrong_answer' => t('Pogrešan tačan odgovor', 'Погрешан тачан одговор'),
      'bad_wording' => t('Loše formulisano', 'Лоше формулисано'),
      'text_error' => t('Greška u tekstu', 'Грешка у тексту'),
      'missing_answer' => t(
        'Nedostaje tačan odgovor',
        'Недостаје тачан одговор',
      ),
      'duplicate' => t('Duplikat', 'Дупликат'),
      'inappropriate' => t('Neprikladno', 'Неприкладно'),
      _ => t('Drugo', 'Друго'),
    };
  }

  String _draftTitle(_ContentReportDraft draft) {
    final snapshot = draft.contentSnapshot;
    final text = snapshot['question_text']?.toString().trim().isNotEmpty == true
        ? snapshot['question_text'].toString().trim()
        : snapshot['prompt']?.toString().trim().isNotEmpty == true
        ? snapshot['prompt'].toString().trim()
        : draft.contentType == 'association'
        ? t('Asocijacija', 'Асоцијација')
        : t('Pitanje', 'Питање');

    final title = s(text);
    if (draft.associationTarget != null) {
      return '$title (${associationLabel(draft.associationTarget)})';
    }

    return title;
  }

  Future<void> _openContentReportSheet(OnlineRound round) async {
    if (!_canReportRound(round)) {
      return;
    }

    final key = _reportKeyFor(round);
    final existing = _contentReportDrafts[key];
    var selectedReason = existing?.reason ?? 'wrong_answer';
    final commentCtrl = TextEditingController(
      text: existing?.userComment ?? '',
    );
    final fixCtrl = TextEditingController(text: existing?.suggestedFix ?? '');

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + bottomInset),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag_rounded, color: context.errorColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t('Prijavi problem', 'Пријави проблем'),
                                style: TextStyle(
                                  color: context.strongText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedReason,
                          decoration: InputDecoration(
                            labelText: t('Razlog', 'Разлог'),
                            border: const OutlineInputBorder(),
                          ),
                          items:
                              const [
                                    'wrong_answer',
                                    'bad_wording',
                                    'text_error',
                                    'missing_answer',
                                    'duplicate',
                                    'inappropriate',
                                    'other',
                                  ]
                                  .map(
                                    (reason) => DropdownMenuItem<String>(
                                      value: reason,
                                      child: Text(_reportReasonLabel(reason)),
                                    ),
                                  )
                                  .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setSheetState(() => selectedReason = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: commentCtrl,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: InputDecoration(
                            labelText: t('Komentar', 'Коментар'),
                            hintText: t(
                              'Zašto mislite da je loše ili pogrešno?',
                              'Зашто мислите да је лоше или погрешно?',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: fixCtrl,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: InputDecoration(
                            labelText: t(
                              'Predlog ispravke',
                              'Предлог исправке',
                            ),
                            hintText: t(
                              'Ako znate kako treba da glasi.',
                              'Ако знате како треба да гласи.',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(false),
                                child: Text(t('Otkaži', 'Откажи')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(true),
                                icon: const Icon(Icons.bookmark_rounded),
                                label: Text(t('Sačuvaj', 'Сачувај')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (saved != true || !mounted) {
        return;
      }

      final comment = commentCtrl.text.trim();
      final fix = fixCtrl.text.trim();
      final draft = existing == null
          ? _ContentReportDraft(
              clientReportId: _newReportId(round),
              sessionId: widget.sessionId,
              roundKey: round.roundKey,
              mode: widget.modeKey,
              contentType: _contentTypeFor(round),
              questionSource: round.questionSource,
              questionId: round.questionId!,
              associationTarget: _associationTargetForReport(round),
              reason: selectedReason,
              userComment: comment.isEmpty ? null : comment,
              suggestedFix: fix.isEmpty ? null : fix,
              contentSnapshot: Map<String, dynamic>.from(round.payload),
            )
          : existing.copyWith(
              reason: selectedReason,
              userComment: comment.isEmpty ? null : comment,
              suggestedFix: fix.isEmpty ? null : fix,
              submitted: false,
            );

      _updateState(() {
        _contentReportDrafts[key] = draft;
        _contentReportSubmitError = null;
      });
      KvizAnalytics.contentReportDraftSaved(
        mode: widget.modeKey,
        contentType: draft.contentType,
        reason: draft.reason,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Sačuvano za kraj partije.', 'Сачувано за крај партије.'),
          ),
        ),
      );
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        commentCtrl.dispose();
        fixCtrl.dispose();
      });
    }
  }

  Future<void> _submitContentReports() async {
    final pending = _contentReportDrafts.entries
        .where((entry) => !entry.value.submitted)
        .toList(growable: false);
    if (pending.isEmpty || _contentReportsSubmitting) {
      return;
    }

    _updateState(() {
      _contentReportsSubmitting = true;
      _contentReportSubmitError = null;
    });

    try {
      for (final entry in pending) {
        final draft = entry.value;
        await _withMobileSessionRetry(
          (mobileSessionToken) => widget.api.submitContentReport(
            accessToken: widget.accessToken,
            mobileSessionToken: mobileSessionToken,
            clientReportId: draft.clientReportId,
            sessionId: draft.sessionId,
            roundKey: draft.roundKey,
            mode: draft.mode,
            contentType: draft.contentType,
            questionSource: draft.questionSource,
            questionId: draft.questionId,
            associationTarget: draft.associationTarget,
            reason: draft.reason,
            userComment: draft.userComment,
            suggestedFix: draft.suggestedFix,
            contentSnapshot: draft.contentSnapshot,
            answerContext: <String, dynamic>{
              if (draft.associationTarget != null)
                'association_target': draft.associationTarget,
            },
          ),
        );
        _contentReportDrafts[entry.key] = draft.copyWith(submitted: true);
        KvizAnalytics.contentReportSubmitSuccess(
          mode: widget.modeKey,
          contentType: draft.contentType,
          reason: draft.reason,
        );
      }

      if (mounted) {
        _updateState(() {
          _contentReportsSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('Prijave su poslate.', 'Пријаве су послате.')),
          ),
        );
      }
    } catch (_) {
      for (final entry in pending) {
        final draft = entry.value;
        KvizAnalytics.contentReportSubmitFailed(
          mode: widget.modeKey,
          contentType: draft.contentType,
          reason: draft.reason,
        );
      }
      if (mounted) {
        _updateState(() {
          _contentReportsSubmitting = false;
          _contentReportSubmitError = t(
            'Slanje nije uspelo. Pokušajte ponovo.',
            'Слање није успело. Покушајте поново.',
          );
        });
      }
    }
  }

  Future<void> _openContentReportDraftEditor(
    String key,
    _ContentReportDraft draft,
  ) async {
    var selectedReason = draft.reason;
    final commentCtrl = TextEditingController(text: draft.userComment ?? '');
    final fixCtrl = TextEditingController(text: draft.suggestedFix ?? '');

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + bottomInset),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          s(_draftTitle(draft)),
                          style: TextStyle(
                            color: context.strongText,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: selectedReason,
                          decoration: InputDecoration(
                            labelText: t('Razlog', 'Разлог'),
                            border: const OutlineInputBorder(),
                          ),
                          items:
                              const [
                                    'wrong_answer',
                                    'bad_wording',
                                    'text_error',
                                    'missing_answer',
                                    'duplicate',
                                    'inappropriate',
                                    'other',
                                  ]
                                  .map(
                                    (reason) => DropdownMenuItem<String>(
                                      value: reason,
                                      child: Text(_reportReasonLabel(reason)),
                                    ),
                                  )
                                  .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setSheetState(() => selectedReason = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: commentCtrl,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: InputDecoration(
                            labelText: t('Komentar', 'Коментар'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: fixCtrl,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: InputDecoration(
                            labelText: t(
                              'Predlog ispravke',
                              'Предлог исправке',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(false),
                                child: Text(t('Otkaži', 'Откажи')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(true),
                                icon: const Icon(Icons.check_rounded),
                                label: Text(t('Sačuvaj', 'Сачувај')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (saved == true && mounted) {
        final comment = commentCtrl.text.trim();
        final fix = fixCtrl.text.trim();
        _updateState(() {
          _contentReportDrafts[key] = draft.copyWith(
            reason: selectedReason,
            userComment: comment.isEmpty ? null : comment,
            suggestedFix: fix.isEmpty ? null : fix,
            submitted: false,
          );
          _contentReportSubmitError = null;
        });
      }
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        commentCtrl.dispose();
        fixCtrl.dispose();
      });
    }
  }
}
