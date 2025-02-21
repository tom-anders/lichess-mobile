import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/tournament/tournament.dart';
import 'package:lichess_mobile/src/model/tournament/tournament_controller.dart';
import 'package:lichess_mobile/src/styles/lichess_colors.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/widgets/platform_scaffold.dart';
import 'package:logging/logging.dart';

final _logger = Logger('TournamentScreen');

class TournamentScreen extends ConsumerWidget {
  const TournamentScreen({required this.id});

  final TournamentId id;

  static Route<void> buildRoute(BuildContext context, TournamentId id) {
    return buildScreenRoute(
      context,
      title: context.l10n.tournament,
      screen: TournamentScreen(id: id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(tournamentControllerProvider(id))) {
      AsyncError(:final error) => Center(child: Text('Could not load tournament: $error')),
      AsyncValue(:final value?) => _Body(state: value),
      _ => const PlatformScaffold(
        appBarTitle: SizedBox.shrink(),
        body: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final TournamentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlatformScaffold(
      appBarTitle: Text(state.name),
      body: Padding(
        padding: Styles.bodySectionPadding,
        child: SingleChildScrollView(
          child: Column(children: [_Verdicts(state.tournament.verdicts)]),
        ),
      ),
    );
  }
}

class _Verdicts extends StatelessWidget {
  const _Verdicts(this.verdicts);

  final Verdicts verdicts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          verdicts.accepted ? Icons.check : Icons.lock,
          color: verdicts.accepted ? LichessColors.good : LichessColors.error,
          size: 40,
        ),
        Column(
          children: verdicts.list
              .map(
                (verdict) => Text(
                  verdict.condition,
                  style: TextStyle(color: verdict.ok ? LichessColors.good : LichessColors.error),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
