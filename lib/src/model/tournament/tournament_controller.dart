import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/socket.dart';
import 'package:lichess_mobile/src/model/tournament/tournament.dart';
import 'package:lichess_mobile/src/model/tournament/tournament_repository.dart';
import 'package:lichess_mobile/src/network/socket.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tournament_controller.freezed.dart';
part 'tournament_controller.g.dart';

const int kStandingsPageSize = 10;

@riverpod
class TournamentController extends _$TournamentController {
  StreamSubscription<SocketEvent>? _socketSubscription;

  late final SocketClient _socketClient;

  @override
  Future<TournamentState> build(TournamentId id) async {
    final state = await _loadTournament(id, standingsPage: 1);

    final socketPool = ref.watch(socketPoolProvider);
    _socketClient = socketPool.open(Uri(path: '/tournament/$id/socket/v6'));
    ref.onDispose(() {
      _socketSubscription?.cancel();
    });

    _socketSubscription?.cancel();
    _socketSubscription = _socketClient.stream.listen(_handleSocketEvent);

    return state;
  }

  Future<TournamentState> _loadTournament(TournamentId id, {required int standingsPage}) async {
    final tournament = await ref
        .read(tournamentRepositoryProvider)
        .getTournament(id, standingsPage: standingsPage);
    return TournamentState(tournament: tournament, standingsPage: standingsPage);
  }

  void loadNextStandingsPage() {
    if (state.hasValue) {
      _refresh(standingsPage: state.requireValue.standingsPage + 1);
    }
  }

  void loadPreviousStandingsPage() {
    if (state.hasValue) {
      _refresh(standingsPage: state.requireValue.standingsPage - 1);
    }
  }

  void loadFirstStandingsPage() {
    _refresh(standingsPage: 1);
  }

  void loadLastStandingsPage() {
    if (state.hasValue) {
      _refresh(standingsPage: state.requireValue.tournament.nbPlayers ~/ kStandingsPageSize + 1);
    }
  }

  Future<void> _refresh({required int standingsPage}) async {
    final state = this.state.valueOrNull;
    if (state == null) {
      return;
    }
    this.state = AsyncValue.data(
      TournamentState(
        tournament: await ref
            .read(tournamentRepositoryProvider)
            .refresh(state.tournament, standingsPage: standingsPage),
        standingsPage: standingsPage,
      ),
    );
  }

  void _handleSocketEvent(SocketEvent event) {
    print('Received socket event: $event');
    if (!state.hasValue) {
      assert(false, 'received a game SocketEvent while TournamentState is null');
      return;
    }
    // TODO call refresh when we receive a reload event
    switch (event.topic) {
      // TODO handle events here
    }
  }
}

@freezed
class TournamentState with _$TournamentState {
  const TournamentState._();

  const factory TournamentState({required Tournament tournament, required int standingsPage}) =
      _TournamentState;

  String get name => tournament.fullName;
}
