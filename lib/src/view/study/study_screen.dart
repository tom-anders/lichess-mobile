import 'package:chessground/chessground.dart';
import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/study/study_controller.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/view/study/study_tree_view.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
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
            title: Text(state.currentChapterTitle),
          ),
          body: _Body(id: id),
        );
      },
      loading: () {
        return const PlatformScaffold(
          appBar: PlatformAppBar(
            title: Text(''),
          ),
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, st) {
        _logger.severe('Cannot load study: $error', st);
        Navigator.of(context).pop();
        return const SizedBox.shrink();
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.id,
  });

  final StudyId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
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

                final direction =
                    aspectRatio > 1 ? Axis.horizontal : Axis.vertical;

                return Flex(
                  direction: direction,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _StudyBoard(
                      id: id,
                      boardSize: boardSize,
                      isTablet: isTablet,
                    ),
                    Expanded(child: StudyTreeView(id)),
                  ],
                );
              },
            ),
          ),
          _BottomBar(id: id),
        ],
      ),
    );
  }
}

extension on PgnCommentShape {
  Shape get chessground {
    final shapeColor = switch (color) {
      CommentShapeColor.green => ShapeColor.green,
      CommentShapeColor.red => ShapeColor.red,
      CommentShapeColor.blue => ShapeColor.blue,
      CommentShapeColor.yellow => ShapeColor.yellow,
    };
    return from != to
        ? Arrow(
            color: shapeColor.color,
            orig: from,
            dest: to,
          )
        : Circle(color: shapeColor.color, orig: from);
  }
}

class _StudyBoard extends ConsumerWidget {
  const _StudyBoard({
    required this.id,
    required this.boardSize,
    required this.isTablet,
  });

  final StudyId id;

  final double boardSize;

  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardPrefs = ref.watch(boardPreferencesProvider);
    final studyState = ref.watch(studyControllerProvider(id)).requireValue;

    final showVariationArrows = true; // TODO make this a setting

    final legalPosition = studyState.currentNode != null;
    final shapes = (!legalPosition || studyState.currentNode!.isRoot
                ? studyState.pgnRootComments
                : studyState.currentNode!.comments)
            ?.map((comment) => comment.shapes)
            .flattened
            .map((shape) => shape.chessground)
            .toList() ??
        [];

    final variationArrows = (showVariationArrows &&
            legalPosition &&
            studyState.currentNode!.children.length > 1)
        ? studyState.currentNode!.children.mapIndexed((i, move) {
            final color = Colors.white.withValues(alpha: i == 0 ? 0.9 : 0.5);
            return Arrow(
              color: color,
              orig: (move as NormalMove).from,
              dest: move.to,
            );
          }).toList()
        : <Shape>[];

    final position = studyState.currentNode?.position;

    return Chessboard(
      size: boardSize,
      settings: boardPrefs.toBoardSettings().copyWith(
            borderRadius: isTablet
                ? const BorderRadius.all(Radius.circular(4.0))
                : BorderRadius.zero,
            boxShadow: isTablet ? boardShadows : const <BoxShadow>[],
          ),
      fen: studyState.position?.board.fen ??
          studyState.study.currentChapterMeta.fen ??
          kInitialFEN,
      orientation: studyState.pov,
      shapes: [...shapes, ...variationArrows].toISet(),
      game: studyState.position != null
          ? GameData(
              playerSide: PlayerSide.both,
              isCheck: position!.isCheck,
              sideToMove: position.turn,
              validMoves: makeLegalMoves(position),
              promotionMove: studyState.promotionMove,
              onMove: (move, {isDrop, captured}) {
                ref.read(studyControllerProvider(id).notifier).onUserMove(move);
              },
              onPromotionSelection: (role) {
                ref
                    .read(studyControllerProvider(id).notifier)
                    .onPromotionSelection(role);
              },
            )
          : null,
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.id,
  });

  final StudyId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studyProvider = studyControllerProvider(id);
    final canGoBack = ref.watch(
      studyProvider.select((value) => value.valueOrNull?.canGoBack ?? false),
    );
    final canGoNext = ref.watch(
      studyProvider.select((value) => value.valueOrNull?.canGoNext ?? false),
    );
    final hasNextChapter = ref.watch(
      studyProvider
          .select((value) => value.valueOrNull?.hasNextChapter ?? false),
    );

    final chapters = ref.watch(
      studyProvider.select(
        (value) => value.valueOrNull?.study.chapters ?? const IList.empty(),
      ),
    );

    final currentChapterId = ref.watch(
      studyProvider.select(
        (value) => value.valueOrNull?.currentChapter.id,
      ),
    );

    final onGoForward =
        canGoNext ? ref.read(studyProvider.notifier).userNext : null;
    final onGoBack =
        canGoBack ? ref.read(studyProvider.notifier).userPrevious : null;

    return BottomBar(
      children: [
        BottomBarButton(
          label: 'Chapters',
          icon: Icons.menu,
          onTap: () => showAdaptiveDialog<void>(
            context: context,
            builder: (context) {
              return SimpleDialog(
                title: const Text('Chapters'),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: ListView.separated(
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        final selected = chapter.id == currentChapterId;
                        final checkedIcon = Theme.of(context).platform ==
                                TargetPlatform.android
                            ? const Icon(Icons.check)
                            : Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                color: CupertinoTheme.of(context).primaryColor,
                              );
                        return PlatformListTile(
                          selected: selected,
                          trailing: selected ? checkedIcon : null,
                          title: Text(chapter.name),
                          onTap: () {
                            ref.read(studyProvider.notifier).goToChapter(
                                  chapter.id,
                                );
                            Navigator.of(context).pop();
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const PlatformDivider(
                        height: 1,
                      ),
                      itemCount: chapters.length,
                    ),
                  ),
                ],
              );
            },
          ),
          showTooltip: false,
        ),
        RepeatButton(
          onLongPress: onGoBack,
          child: BottomBarButton(
            key: const ValueKey('goto-previous'),
            onTap: onGoBack,
            label: 'Previous',
            icon: CupertinoIcons.chevron_back,
            showTooltip: false,
          ),
        ),
        RepeatButton(
          onLongPress: onGoForward,
          child: BottomBarButton(
            key: const ValueKey('goto-next'),
            icon: CupertinoIcons.chevron_forward,
            onTap: onGoForward,
            label: context.l10n.next,
            showTooltip: false,
          ),
        ),
      ],
    );
  }
}
