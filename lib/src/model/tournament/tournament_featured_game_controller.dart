import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/service/sound_service.dart';
import 'package:lichess_mobile/src/model/common/socket.dart';
import 'package:lichess_mobile/src/model/game/game.dart';
import 'package:lichess_mobile/src/model/game/game_socket_events.dart';
import 'package:lichess_mobile/src/model/game/game_status.dart';
import 'package:lichess_mobile/src/model/game/material_diff.dart';
import 'package:lichess_mobile/src/model/game/playable_game.dart';
import 'package:lichess_mobile/src/model/tournament/tournament.dart';
import 'package:lichess_mobile/src/model/tv/tv_channel.dart';
import 'package:lichess_mobile/src/model/tv/tv_repository.dart';
import 'package:lichess_mobile/src/model/tv/tv_socket_events.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/network/socket.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tournament_featured_game_controller.freezed.dart';
part 'tournament_featured_game_controller.g.dart';

@riverpod
class TournamentFeaturedGameController extends _$TournamentFeaturedGameController {
  StreamSubscription<SocketEvent>? _socketSubscription;

  @override
  Future<FeaturedGameState> build(FeaturedGame game) async {
    ref.onDispose(() {
      _socketSubscription?.cancel();
    });

    final socketClient = ref
        .read(socketPoolProvider)
        .open(Uri(path: '/watch/${game.id}/${game.orientation}/v6'));

    _socketSubscription?.cancel();
    _socketSubscription = socketClient.stream.listen(_handleSocketEvent);

    return socketClient.stream.firstWhere((e) => e.topic == 'full').then((event) {
      return FeaturedGameState(
        game: GameFullEvent.fromJson(event.data as Map<String, dynamic>).game,
      );
    });
  }

  Future<void> _moveToNextGame((GameId id, Side orientation) game) async {
    final newState = await _connectWebsocket(game);
    state = AsyncValue.data(newState);
  }

  bool canGoBack() => state.mapOrNull(data: (d) => d.value.stepCursor > 0) ?? false;

  bool canGoForward() =>
      state.mapOrNull(data: (d) => d.value.stepCursor < d.value.game.steps.length - 1) ?? false;

  void toggleBoard() {
    if (state.hasValue) {
      final curState = state.requireValue;
      state = AsyncValue.data(curState.copyWith(orientation: curState.orientation.opposite));
    }
  }

  void cursorForward() {
    if (state.hasValue) {
      final curState = state.requireValue;
      if (curState.stepCursor < curState.game.steps.length - 1) {
        state = AsyncValue.data(curState.copyWith(stepCursor: curState.stepCursor + 1));
        final san = curState.game.stepAt(curState.stepCursor + 1).sanMove?.san;
        if (san != null) {
          _playReplayMoveSound(san);
        }
      }
    }
  }

  void cursorBackward() {
    if (state.hasValue) {
      final curState = state.requireValue;
      if (curState.stepCursor > 0) {
        state = AsyncValue.data(curState.copyWith(stepCursor: curState.stepCursor - 1));
        final san = curState.game.stepAt(curState.stepCursor - 1).sanMove?.san;
        if (san != null) {
          _playReplayMoveSound(san);
        }
      }
    }
  }

  void _playReplayMoveSound(String san) {
    final soundService = ref.read(soundServiceProvider);
    if (san.contains('x')) {
      soundService.play(Sound.capture);
    } else {
      soundService.play(Sound.move);
    }
  }

  void _handleSocketEvent(SocketEvent event) {
    if (!state.hasValue) {
      assert(false, 'received a game SocketEvent while TournamentState is null');
      return;
    }

    switch (event.topic) {
      case 'move':
        final curState = state.requireValue;
        final data = MoveEvent.fromJson(event.data as Map<String, dynamic>);
        final lastPos = curState.game.lastPosition;
        final move = Move.parse(data.uci)!;
        final sanMove = SanMove(data.san, move);
        final newPos = lastPos.playUnchecked(move);
        final newStep = GameStep(
          sanMove: sanMove,
          position: newPos,
          diff: MaterialDiff.fromBoard(newPos.board),
        );

        FeaturedGameState newState = curState.copyWith(
          game: curState.game.copyWith(steps: curState.game.steps.add(newStep)),
        );

        if (newState.game.clock != null && data.clock != null) {
          newState = newState.copyWith.game.clock!(
            white: data.clock!.white,
            black: data.clock!.black,
            lag: data.clock!.lag,
            at: data.clock!.at,
          );
        }

        state = AsyncData(newState);

      case 'endData':
        final endData = GameEndEvent.fromJson(event.data as Map<String, dynamic>);
        FeaturedGameState newState = state.requireValue.copyWith(
          game: state.requireValue.game.copyWith(status: endData.status, winner: endData.winner),
        );
        if (endData.clock != null) {
          newState = newState.copyWith.game.clock!(
            white: endData.clock!.white,
            black: endData.clock!.black,
            at: DateTime.now(),
            lag: null,
          );
        }
        state = AsyncData(newState);
    }
  }
}

@freezed
class FeaturedGameState with _$FeaturedGameState {
  const FeaturedGameState._();

  const factory FeaturedGameState({required PlayableGame game}) = _FeaturedGameState;

  Side? get activeClockSide {
    if (game.clock == null) {
      return null;
    }

    if (game.status == GameStatus.started) {
      final pos = game.lastPosition;
      if (pos.fullmoves > 1) {
        return pos.turn;
      }
    }

    return null;
  }
}
