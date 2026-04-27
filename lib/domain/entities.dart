class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.difficulty,
    this.status = 'valid',
  });

  final int id;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final int correctOption;
  final String difficulty;

  /// 'valid', 'review', 'invalid' — iz baze
  final String status;
}

class AssociationPuzzle {
  const AssociationPuzzle({
    required this.id,
    required this.cluesA,
    required this.cluesB,
    required this.cluesC,
    required this.cluesD,
    required this.solutionA,
    required this.solutionB,
    required this.solutionC,
    required this.solutionD,
    required this.solutionFinal,
    this.status = 'review',
    this.isVerified = false,
  });

  final int id;
  final List<String> cluesA;
  final List<String> cluesB;
  final List<String> cluesC;
  final List<String> cluesD;
  final String solutionA;
  final String solutionB;
  final String solutionC;
  final String solutionD;
  final String solutionFinal;

  /// 'accepted', 'rejected', 'review' — iz baze
  final String status;

  /// Da li je asocijacija verifikovana
  final bool isVerified;
}

class MyNumberPuzzle {
  const MyNumberPuzzle({
    required this.id,
    required this.target,
    required this.numbers,
    required this.sampleSolution,
    required this.difficulty,
  });

  final int id;
  final int target;
  final List<int> numbers;
  final String sampleSolution;
  final String difficulty;
}

class TangramPuzzle {
  const TangramPuzzle({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.timeLimitSeconds,
    required this.hint,
    this.status = 'active',
  });

  final int id;
  final String title;
  final String difficulty;
  final int timeLimitSeconds;
  final String hint;

  /// 'active', 'draft' — iz baze
  final String status;
}

class GameTimerConfig {
  const GameTimerConfig({required this.gameKey, required this.durationSeconds});

  final String gameKey;
  final int durationSeconds;
}

class RoundInfo {
  const RoundInfo({required this.gameKey, required this.title});

  final String gameKey;
  final String title;
}

enum ModeKind { quiz, questions, associations, myNumber, tangram, premier }
