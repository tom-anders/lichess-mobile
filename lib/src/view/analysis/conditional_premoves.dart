import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/account/account_preferences.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/common/node.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';

class ConditionalPremoves extends ConsumerWidget {
  const ConditionalPremoves(this.options);

  final AnalysisOptions options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrlProvider = analysisControllerProvider(options);
    final analysisState = ref.watch(ctrlProvider).requireValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...analysisState.forecast!.lines.map(
          (line) => _Variation(startingBranch: analysisState.liveMoveBranch!, path: line),
        ),
        if (analysisState.currentPremoveCandidate != null) Text('can add!') else Text('nope'),
      ],
    );
  }
}

class _Variation extends ConsumerWidget {
  const _Variation({required this.startingBranch, required this.path});

  final ViewBranch startingBranch;

  final UciPath path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = startingBranch.branchesOn(path);

    final pieceNotation = ref
        .watch(pieceNotationProvider)
        .maybeWhen(data: (value) => value, orElse: () => defaultAccountPreferences.pieceNotation);

    return InkWell(
      borderRadius: BorderRadius.all(Radius.circular(4.0)),
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(4.0),
        child: Text(
          maxLines: 1,
          style: TextStyle(
            fontSize: 16,
            fontFamily: pieceNotation == PieceNotation.symbol ? 'ChessFont' : null,
          ),
          nodes
              .mapIndexed((i, node) {
                final indexText = i == 0 && node.position.turn == Side.white
                    ? '${node.position.fullmoves - 1}..'
                    : i == 0 || node.position.turn == Side.black
                    ? '${node.position.fullmoves}.'
                    : '';
                return '$indexText ${node.sanMove.san}';
              })
              .join(' '),
        ),
      ),
    );
  }
}
