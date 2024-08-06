import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'coordinate_training_controller.freezed.dart';
part 'coordinate_training_controller.g.dart';

@riverpod
class CoordinateTrainingController extends _$CoordinateTrainingController {
  final _random = Random(DateTime.now().millisecondsSinceEpoch);

  final _stopwatch = Stopwatch();
  Timer? _updateTimer;

  @override
  CoordinateTrainingState build() {
    return const CoordinateTrainingState(
      currentCoord: null,
      nextCoord: null,
      score: 0,
      timeLimit: null,
      elapsed: null,
    );
  }

  void startTraining(Duration? timeLimit) {
    final currentCoord = randomCoord();
    state = state.copyWith(
      currentCoord: currentCoord,
      nextCoord: randomCoord(prev: currentCoord),
      score: 0,
      timeLimit: timeLimit,
      elapsed: Duration.zero,
    );

    _updateTimer?.cancel();
    _stopwatch.reset();
    _stopwatch.start();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (state.timeLimit != null && _stopwatch.elapsed > state.timeLimit!) {
        stopTraining();
      } else {
        state = state.copyWith(
          elapsed: _stopwatch.elapsed,
        );
      }
    });
  }

  void stopTraining() {
    _updateTimer?.cancel();
    state = state.copyWith(
      elapsed: null,
    );
  }

  Square randomCoord({Square? prev}) {
    while (true) {
      final square = Square.values[_random.nextInt(Square.values.length)];
      if (square != prev) {
        return square;
      }
    }
  }

  bool onGuessCoord(Square coord) {
    final correctGuess = coord == state.currentCoord;

    if (correctGuess) {
      state = state.copyWith(
        currentCoord: state.nextCoord,
        nextCoord: randomCoord(prev: state.nextCoord),
        score: state.score + 1,
      );
    }

    return correctGuess;
  }
}

@freezed
class CoordinateTrainingState with _$CoordinateTrainingState {
  const CoordinateTrainingState._();

  const factory CoordinateTrainingState({
    required Square? currentCoord,
    required Square? nextCoord,
    required int score,
    required Duration? timeLimit,
    required Duration? elapsed,
  }) = _CoordinateTrainingState;

  bool get trainingActive => elapsed != null;

  double? get timePercentageElapsed => (elapsed != null && timeLimit != null)
      ? elapsed!.inMilliseconds / timeLimit!.inMilliseconds
      : null;
}
