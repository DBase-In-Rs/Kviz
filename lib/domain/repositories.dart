import 'entities.dart';

abstract class QuizRepository {
  Future<List<QuizQuestion>> fetchQuestions({int limit = 10});
  Future<int> countQuestions();
}

abstract class AssociationRepository {
  Future<List<AssociationPuzzle>> fetchAssociations({int limit = 10});
  Future<int> countAssociations();
}

abstract class MyNumberRepository {
  Future<List<MyNumberPuzzle>> fetchPuzzles({int limit = 10});
  Future<int> countPuzzles();
}

abstract class TangramRepository {
  Future<List<TangramPuzzle>> fetchPuzzles({int limit = 10});
  Future<int> countPuzzles();
}

abstract class TimerConfigRepository {
  Future<List<GameTimerConfig>> fetchTimers();
  Future<Map<String, int>> fetchTimerMap();
}
