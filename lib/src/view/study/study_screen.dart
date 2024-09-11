import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/study/study.dart';
import 'package:lichess_mobile/src/model/study/study_controller.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_board.dart';
import 'package:lichess_mobile/src/widgets/board_table.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/platform_scaffold.dart';
import 'package:logging/logging.dart';

final _logger = Logger('StudyScreen');

class StudyScreen extends ConsumerWidget {
  const StudyScreen({
    required this.id,
  });

  final StudyId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyControllerProvider(id));

    return state.when(
      data: (state) {
        return PlatformScaffold(
          appBar: PlatformAppBar(
            title: Text(state.study.name),
          ),
          body: _Body(state: state),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, st) {
        _logger.severe('Cannot load study: $error', st);
        return const Center(
          child: Text('Failed to load study'),
        );
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.state,
  });

  final StudyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = Setup.parseFen(state.initialFen);

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // TODO table layout
                final aspectRatio = constraints.biggest.aspectRatio;
                final defaultBoardSize = constraints.biggest.shortestSide;
                final isTablet = isTabletOrLarger(context);
                final remainingHeight =
                    constraints.maxHeight - defaultBoardSize;
                final isSmallScreen =
                    remainingHeight < kSmallRemainingHeightLeftBoardThreshold;
                final boardSize = isTablet || isSmallScreen
                    ? defaultBoardSize - kTabletBoardTableSidePadding * 2
                    : defaultBoardSize;

                return AnalysisBoard(
                  PgnGame(
                    headers: {'FEN': setup.fen},
                    moves: PgnNode<PgnNodeData>(),
                    comments: [],
                  ).makePgn(),
                  AnalysisOptions(
                    isLocalEvaluationAllowed: false,
                    variant: state.currentChapter.setup.variant,
                    orientation: Side.white,
                    id: standaloneAnalysisId,
                  ),
                  boardSize,
                  isTablet: isTablet,
                );
              },
            ),
          ),
          const BottomBar(
            children: [],
          ),
        ],
      ),
    );
  }
}
