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
import 'package:lichess_mobile/src/widgets/list.dart';

class ConditionalPremoves extends ConsumerWidget {
  const ConditionalPremoves(this.options);

  final AnalysisOptions options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrlProvider = analysisControllerProvider(options);
    final analysisState = ref.watch(ctrlProvider).requireValue;

    final lines = analysisState.forecast!.lines;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: lines.length,
                separatorBuilder: (_, _) => const PlatformDivider(),
                itemBuilder: (context, index) => _Variation(
                  options,
                  startingBranch: analysisState.liveMoveBranch!,
                  path: lines[index],
                ),
              ),
            ),
          ),
        ),
        if (analysisState.currentPremoveCandidate != null)
          Row(
            children: [
              FilledButton.tonal(
                onPressed: ref.read(ctrlProvider.notifier).addCurrentPathAsPremove,
                child: Text(context.l10n.addCurrentVariation),
              ),
              _PlayMoveButton(options),
            ],
          )
        else
          Text(context.l10n.playVariationToCreateConditionalPremoves),
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

    return SizedBox.shrink();
  }
}

class _Variation extends ConsumerWidget {
  const _Variation(this.options, {required this.startingBranch, required this.path});

  final AnalysisOptions options;

  final ViewBranch startingBranch;

  final UciPath path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveMovePath = ref.watch(analysisControllerProvider(options)).requireValue.pathToLiveMove;

    final pieceNotation = ref
        .watch(pieceNotationProvider)
        .maybeWhen(data: (value) => value, orElse: () => defaultAccountPreferences.pieceNotation);

    return ListTile(
      visualDensity: VisualDensity.compact,
      onTap: () {
        ref
            .read(analysisControllerProvider(options).notifier)
            .userJump(UciPath.join(liveMovePath!, path));
      },
      titleTextStyle: TextStyle(
        fontSize: 14,
        fontFamily: pieceNotation == PieceNotation.symbol ? 'ChessFont' : null,
        color: ColorScheme.of(context).onSurface,
      ),
      title: Text.rich(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        TextSpan(
          children: startingBranch
              .branchesOn(path)
              .mapIndexed(
                (i, branch) => WidgetSpan(
                  child: _Move(branch: branch, startsLine: i == 0),
                ),
              )
              .toList(growable: false),
        ),
      ),
      trailing: IconButton(
        onPressed: () {
          ref.read(analysisControllerProvider(options).notifier).removePremovePath(path);
        },
        icon: const Icon(CupertinoIcons.delete, size: 20),
        tooltip: context.l10n.delete,
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
