import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/account/account_preferences.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/common/node.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';

class ConditionalPremoves extends ConsumerWidget {
  const ConditionalPremoves(this.options);

  final AnalysisOptions options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrlProvider = analysisControllerProvider(options);
    final analysisState = ref.watch(ctrlProvider).requireValue;

    final lines = analysisState.forecast!.lines;

    final currentCandidate = analysisState.currentPremoveCandidate;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ListView(
                //shrinkWrap: true,
                children: [
                  if (currentCandidate != null)
                    _Variation(
                      options,
                      startingNode: analysisState.liveMoveNode!,
                      path: currentCandidate,
                      trailing: IconButton(
                        onPressed: () {
                          ref
                              .read(analysisControllerProvider(options).notifier)
                              .addCurrentPathAsPremove();
                        },
                        icon: const Icon(Icons.save, size: 20),
                        tooltip: context.l10n.addCurrentVariation,
                      ),
                    ),
                  ...lines
                      .where((line) => currentCandidate?.contains(line) != true)
                      .map(
                        (line) => _Variation(
                          options,
                          startingNode: analysisState.liveMoveNode!,
                          path: line,
                          onTap: () {
                            ref
                                .read(analysisControllerProvider(options).notifier)
                                .userJump(UciPath.join(analysisState.pathToLiveMove!, line));
                          },
                          trailing: IconButton(
                            onPressed: () {
                              ref
                                  .read(analysisControllerProvider(options).notifier)
                                  .removePremovePath(line);
                            },
                            icon: const Icon(CupertinoIcons.delete, size: 20),
                            tooltip: context.l10n.delete,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        _PlayMoveButton(options),
      ],
    );
  }
}

class _PlayMoveButton extends ConsumerWidget {
  const _PlayMoveButton(this.options);

  final AnalysisOptions options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisState = ref.watch(analysisControllerProvider(options)).requireValue;

    if (!analysisState.forecast!.onMyTurn) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }
}

class _Variation extends ConsumerWidget {
  const _Variation(
    this.options, {
    required this.startingNode,
    required this.path,
    this.onTap,
    required this.trailing,
  });

  final AnalysisOptions options;

  final ViewNode startingNode;

  final UciPath path;

  final VoidCallback? onTap;

  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pieceNotation = ref
        .watch(pieceNotationProvider)
        .maybeWhen(data: (value) => value, orElse: () => defaultAccountPreferences.pieceNotation);

    return InkWell(
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Text.rich(
              maxLines: 2,
              style: TextStyle(
                fontSize: 14,
                fontFamily: pieceNotation == PieceNotation.symbol ? 'ChessFont' : null,
                //color: ColorScheme.of(context).onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              TextSpan(
                children: startingNode
                    .branchesOn(path)
                    .mapIndexed(
                      (i, branch) => WidgetSpan(
                        child: _Move(branch: branch, startsLine: i == 0),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _Move extends StatelessWidget {
  const _Move({required this.branch, required this.startsLine});

  final ViewBranch branch;

  final bool startsLine;

  @override
  Widget build(BuildContext context) {
    final indexText = startsLine && branch.position.turn == Side.white
        ? '${branch.position.fullmoves - 1}.. '
        : branch.position.turn == Side.black
        ? '${branch.position.fullmoves}. '
        : '';
    return Text('$indexText${branch.sanMove.san} ');
  }
}
