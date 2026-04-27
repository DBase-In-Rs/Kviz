part of '../online_session_page.dart';

const Object _unchangedContentReportValue = Object();

class _ContentReportDraft {
  const _ContentReportDraft({
    required this.clientReportId,
    required this.sessionId,
    required this.roundKey,
    required this.mode,
    required this.contentType,
    required this.questionSource,
    required this.questionId,
    required this.reason,
    required this.contentSnapshot,
    this.associationTarget,
    this.userComment,
    this.suggestedFix,
    this.submitted = false,
  });

  final String clientReportId;
  final String sessionId;
  final String roundKey;
  final String mode;
  final String contentType;
  final String questionSource;
  final int questionId;
  final String? associationTarget;
  final String reason;
  final String? userComment;
  final String? suggestedFix;
  final Map<String, dynamic> contentSnapshot;
  final bool submitted;

  _ContentReportDraft copyWith({
    String? reason,
    Object? userComment = _unchangedContentReportValue,
    Object? suggestedFix = _unchangedContentReportValue,
    bool? submitted,
  }) {
    return _ContentReportDraft(
      clientReportId: clientReportId,
      sessionId: sessionId,
      roundKey: roundKey,
      mode: mode,
      contentType: contentType,
      questionSource: questionSource,
      questionId: questionId,
      associationTarget: associationTarget,
      reason: reason ?? this.reason,
      userComment: identical(userComment, _unchangedContentReportValue)
          ? this.userComment
          : userComment as String?,
      suggestedFix: identical(suggestedFix, _unchangedContentReportValue)
          ? this.suggestedFix
          : suggestedFix as String?,
      contentSnapshot: contentSnapshot,
      submitted: submitted ?? this.submitted,
    );
  }
}
