import 'package:chessground/chessground.dart';
import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/study/study.dart';
import 'package:lichess_mobile/src/model/study/study_controller.dart';
import 'package:lichess_mobile/src/model/study/study_node.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_board.dart';
import 'package:lichess_mobile/src/view/analysis/annotations.dart';
import 'package:lichess_mobile/src/view/analysis/tree_view.dart';
import 'package:lichess_mobile/src/view/study/study_tree_view.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
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

  // TODO use controller instead
  final StudyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardPrefs = ref.watch(boardPreferencesProvider);

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

                final position = state.currentNode.position;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Chessboard(
                      size: boardSize,
                      settings: boardPrefs.toBoardSettings(),
                      fen: state.currentNode.fen,
                      orientation: state.currentChapter.setup.orientation,
                      shapes: state.currentNode.shapes?.toISet(),
                      game: position != null
                          ? GameData(
                              playerSide: PlayerSide.both,
                              isCheck: position.isCheck,
                              sideToMove: position.turn,
                              validMoves: makeLegalMoves(position),
                              promotionMove: null, // TODO
                              onMove: (move, {isDrop, captured}) {
                                // TODO
                              },
                              onPromotionSelection: (role) {
                                // TODO
                              },
                            )
                          : null,
                    ),
                    Expanded(child: StudyTreeView(state.study.id)),
                  ],
                );
              },
            ),
          ),
          BottomBar(
            children: [
              BottomBarButton(
                icon: Icons.arrow_right,
                label: 'Next Chapter',
                onTap: () {
                  final chapters = state.study.chapters;
                  final currentChapterIndex = chapters.indexWhere(
                    (chapter) => chapter.id == state.study.chapter.id,
                  );
                  ref
                      .read(studyControllerProvider(state.study.id).notifier)
                      .loadChapter(
                        state.study.chapters[currentChapterIndex + 1].id,
                      );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
