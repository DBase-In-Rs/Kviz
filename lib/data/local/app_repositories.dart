import '../../domain/entities.dart';
import '../../domain/repositories.dart';

class AppRepositories {
  const AppRepositories({
    required this.quizRepository,
    required this.associationRepository,
    required this.myNumberRepository,
    required this.tangramRepository,
    required this.timerConfigRepository,
  });

  final QuizRepository quizRepository;
  final AssociationRepository associationRepository;
  final MyNumberRepository myNumberRepository;
  final TangramRepository tangramRepository;
  final TimerConfigRepository timerConfigRepository;
}

AppRepositories createLocalRepositories() {
  return AppRepositories(
    quizRepository: const SampleQuizRepository(),
    associationRepository: const SampleAssociationRepository(),
    myNumberRepository: const SampleMyNumberRepository(),
    tangramRepository: const SampleTangramRepository(),
    timerConfigRepository: const SampleTimerConfigRepository(),
  );
}

class SampleQuizRepository implements QuizRepository {
  const SampleQuizRepository();

  static const _questions = <QuizQuestion>[
    QuizQuestion(
      id: 1,
      question: 'Koji je glavni grad Srbije?',
      optionA: 'Beograd',
      optionB: 'Novi Sad',
      optionC: 'Nis',
      optionD: 'Kragujevac',
      correctOption: 1,
      difficulty: 'lako',
      status: 'valid',
    ),
    QuizQuestion(
      id: 2,
      question: 'Koliko minuta ima jedan sat?',
      optionA: '30',
      optionB: '45',
      optionC: '60',
      optionD: '90',
      correctOption: 3,
      difficulty: 'lako',
      status: 'valid',
    ),
    QuizQuestion(
      id: 3,
      question: 'Koji kontinent je najveci po povrsini?',
      optionA: 'Afrika',
      optionB: 'Azija',
      optionC: 'Evropa',
      optionD: 'Juzna Amerika',
      correctOption: 2,
      difficulty: 'srednje',
      status: 'valid',
    ),
  ];

  @override
  Future<List<QuizQuestion>> fetchQuestions({int limit = 10}) async {
    return _takeLimit(_questions, limit);
  }

  @override
  Future<int> countQuestions() async => _questions.length;
}

class SampleAssociationRepository implements AssociationRepository {
  const SampleAssociationRepository();

  static const _associations = <AssociationPuzzle>[
    AssociationPuzzle(
      id: 1,
      cluesA: ['Kafa', 'Napitak', 'Domaca', 'Zrno'],
      cluesB: ['Mleko', 'Kakao', 'Secer', 'Toplo'],
      cluesC: ['Voda', 'Pritisak', 'Aroma', 'Aparat'],
      cluesD: ['Jutro', 'Pauza', 'Posao', 'Budjenje'],
      solutionA: 'Kafa',
      solutionB: 'Cokolada',
      solutionC: 'Espreso',
      solutionD: 'Jutro',
      solutionFinal: 'Napitak',
      status: 'review',
      isVerified: false,
    ),
    AssociationPuzzle(
      id: 2,
      cluesA: ['Suma', 'List', 'Drvo', 'Plod'],
      cluesB: ['Koren', 'Stablo', 'Krosnja', 'Seme'],
      cluesC: ['Sadi', 'Zaliva', 'Odrzava', 'Voce'],
      cluesD: ['Jabuka', 'Sljiva', 'Kruska', 'Tresnja'],
      solutionA: 'Drvo',
      solutionB: 'Biljka',
      solutionC: 'Basta',
      solutionD: 'Vocka',
      solutionFinal: 'Priroda',
      status: 'review',
      isVerified: false,
    ),
  ];

  @override
  Future<List<AssociationPuzzle>> fetchAssociations({int limit = 10}) async {
    return _takeLimit(_associations, limit);
  }

  @override
  Future<int> countAssociations() async => _associations.length;
}

class SampleMyNumberRepository implements MyNumberRepository {
  const SampleMyNumberRepository();

  static const _puzzles = <MyNumberPuzzle>[
    MyNumberPuzzle(
      id: 1,
      target: 641,
      numbers: [100, 50, 9, 7, 6, 3],
      sampleSolution: '(100 * 6) + 50 - 9',
      difficulty: 'srednje',
    ),
    MyNumberPuzzle(
      id: 2,
      target: 258,
      numbers: [75, 50, 8, 4, 3, 2],
      sampleSolution: '(75 * 3) + 50 - 8 - 4 - 3 - 2',
      difficulty: 'lako',
    ),
  ];

  @override
  Future<List<MyNumberPuzzle>> fetchPuzzles({int limit = 10}) async {
    return _takeLimit(_puzzles, limit);
  }

  @override
  Future<int> countPuzzles() async => _puzzles.length;
}

class SampleTangramRepository implements TangramRepository {
  const SampleTangramRepository();

  static const _puzzles = <TangramPuzzle>[
    TangramPuzzle(
      id: 1,
      title: 'Kuca',
      difficulty: 'lako',
      timeLimitSeconds: 120,
      hint: 'Pocni od velikog trougla kao krova.',
    ),
    TangramPuzzle(
      id: 2,
      title: 'Labud',
      difficulty: 'srednje',
      timeLimitSeconds: 120,
      hint: 'Vrat formiraj od dva srednja trougla.',
    ),
  ];

  @override
  Future<List<TangramPuzzle>> fetchPuzzles({int limit = 10}) async {
    return _takeLimit(_puzzles, limit);
  }

  @override
  Future<int> countPuzzles() async => _puzzles.length;
}

class SampleTimerConfigRepository implements TimerConfigRepository {
  const SampleTimerConfigRepository();

  static const _timers = <GameTimerConfig>[
    GameTimerConfig(gameKey: 'ko_zna_zna', durationSeconds: 100),
    GameTimerConfig(gameKey: 'asocijacije', durationSeconds: 100),
    GameTimerConfig(gameKey: 'moj_broj', durationSeconds: 120),
    GameTimerConfig(gameKey: 'tangram', durationSeconds: 120),
  ];

  @override
  Future<List<GameTimerConfig>> fetchTimers() async => _timers;

  @override
  Future<Map<String, int>> fetchTimerMap() async {
    return {for (final timer in _timers) timer.gameKey: timer.durationSeconds};
  }
}

List<T> _takeLimit<T>(List<T> items, int limit) {
  if (limit <= 0) {
    return const [];
  }

  if (items.length <= limit) {
    return List<T>.unmodifiable(items);
  }

  return List<T>.unmodifiable(items.take(limit));
}
