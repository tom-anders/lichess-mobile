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

@riverpod
class TournamentController extends _$TournamentController {
  StreamSubscription<SocketEvent>? _socketSubscription;

  late final SocketClient _socketClient;

  @override
  Future<TournamentState> build(TournamentId id) async {
    final tournament = await ref
        .read(tournamentRepositoryProvider)
        .getTournament(id, standingsPage: 1);

    final socketPool = ref.watch(socketPoolProvider);
    _socketClient = socketPool.open(Uri(path: '/tournament/$id/socket/v6'));
    ref.onDispose(() {
      _socketSubscription?.cancel();
    });

    _socketSubscription?.cancel();
    _socketSubscription = _socketClient.stream.listen(_handleSocketEvent);

    return TournamentState(tournament: tournament, standingsPage: 1);
  }

  void _handleSocketEvent(SocketEvent event) {
    print('Received socket event: $event');
    if (!state.hasValue) {
      assert(false, 'received a game SocketEvent while TournamentState is null');
      return;
    }
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
