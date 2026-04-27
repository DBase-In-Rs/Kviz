part of '../online_session_page.dart';

extension _OnlineSessionTangramWidgets on _OnlineSessionPageState {
  Widget _buildTangramPayload(OnlineRound round) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          round.title == null ? t('Tangram', 'Танграм') : s(round.title),
          style: TextStyle(
            color: context.strongText,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${t('Težina', 'Тежина')}: ${s(round.difficulty ?? '-')}',
          style: TextStyle(
            color: context.accentText,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        _buildTangramInteraction(round),
        if ((round.hint ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '${t('Savet', 'Савет')}: ${s(round.hint)}',
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

  Widget _buildTangramInteraction(OnlineRound round) {
    final selectedPiece = _selectedTangramPieceId == null
        ? null
        : _tangramPieces[_selectedTangramPieceId];
    final disabled =
        _inputState == _InputState.submitting ||
        _inputState == _InputState.answered ||
        _sessionStatus != 'active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final boardSize = constraints.biggest;
                  return RawGestureDetector(
                    key: const ValueKey<String>('online_tangram_board'),
                    gestures: disabled
                        ? const <Type, GestureRecognizerFactory>{}
                        : <Type, GestureRecognizerFactory>{
                            EagerGestureRecognizer:
                                GestureRecognizerFactoryWithHandlers<
                                  EagerGestureRecognizer
                                >(EagerGestureRecognizer.new, (recognizer) {}),
                          },
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: disabled
                          ? null
                          : (event) => _startTangramDrag(
                              round,
                              event.localPosition,
                              boardSize,
                            ),
                      onPointerMove: disabled
                          ? null
                          : (event) => _moveSelectedTangramPiece(
                              round,
                              event.delta,
                              boardSize,
                            ),
                      onPointerUp: disabled ? null : (_) => _endTangramDrag(),
                      onPointerCancel: disabled
                          ? null
                          : (_) => _endTangramDrag(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.innerBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _TangramInteractionPainter(
                                shape: round.tangramShape,
                                pieces: _tangramPieces.values.toList(),
                                selectedPieceId: _selectedTangramPieceId,
                                targetFillColor: context.accentText.withValues(
                                  alpha: 0.16,
                                ),
                                targetOutlineColor: context.accentText
                                    .withValues(alpha: 0.62),
                                pieceFillColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                pieceOutlineColor: context.strongText
                                    .withValues(alpha: 0.74),
                                selectedColor: context.actionBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t(
            'Prevuci svih 7 delova na siluetu. Izabrani deo mozes da rotiras ili okrenes.',
            'Превуци свих 7 делова на силуету. Изабрани део можеш да ротираш или окренеш.',
          ),
          style: TextStyle(
            color: context.mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: Icon(
                Icons.category_rounded,
                size: 18,
                color: context.accentText,
              ),
              label: Text(
                selectedPiece == null
                    ? t('Izaberi deo', 'Изабери део')
                    : _tangramPieceLabel(selectedPiece),
                style: TextStyle(
                  color: context.strongText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              backgroundColor: context.cardBg,
              side: BorderSide(color: context.borderColor),
            ),
            OutlinedButton.icon(
              onPressed: disabled || selectedPiece == null
                  ? null
                  : () => _rotateSelectedTangramPiece(-45),
              icon: const Icon(Icons.rotate_left_rounded),
              label: Text(t('Levo', 'Лево')),
            ),
            OutlinedButton.icon(
              onPressed: disabled || selectedPiece == null
                  ? null
                  : () => _rotateSelectedTangramPiece(45),
              icon: const Icon(Icons.rotate_right_rounded),
              label: Text(t('Desno', 'Десно')),
            ),
            OutlinedButton.icon(
              onPressed: disabled || selectedPiece == null
                  ? null
                  : _flipSelectedTangramPiece,
              icon: const Icon(Icons.flip_rounded),
              label: Text(t('Okreni', 'Окрени')),
            ),
            OutlinedButton.icon(
              onPressed: disabled
                  ? null
                  : () => _updateState(() => _resetTangramPieces()),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(t('Reset', 'Ресет')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTangramAction() {
    final isSubmitting = _inputState == _InputState.submitting;
    final disabled =
        isSubmitting ||
        _inputState == _InputState.answered ||
        _sessionStatus != 'active';

    return SizedBox(
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
        onPressed: disabled ? null : _submitTangramSolution,
        icon: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_rounded),
        label: Text(
          t('Završio sam slaganje', 'Завршио сам слагање'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
