import 'package:chessground/chessground.dart';
import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_preferences.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/engine/evaluation_service.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/study/study_controller.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/view/analysis/annotations.dart';
import 'package:lichess_mobile/src/view/engine/engine_gauge.dart';
import 'package:lichess_mobile/src/view/engine/engine_lines.dart';
import 'package:lichess_mobile/src/view/study/study_gamebook.dart';
import 'package:lichess_mobile/src/view/study/study_settings.dart';
import 'package:lichess_mobile/src/view/study/study_tree_view.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
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
            actions: [
              AppBarIconButton(
                onPressed: () => showAdaptiveBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  isDismissible: true,
                  builder: (_) => StudySettings(id),
                ),
                semanticsLabel: context.l10n.settingsSettings,
                icon: const Icon(Icons.settings),
              ),
            ],
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
                final defaultBoardSize = constraints.biggest.shortestSide;
                final isTablet = isTabletOrLarger(context);
                final remainingHeight =
                    constraints.maxHeight - defaultBoardSize;
                final isSmallScreen =
                    remainingHeight < kSmallRemainingHeightLeftBoardThreshold;
                final boardSize = isTablet || isSmallScreen
                    ? defaultBoardSize - kTabletBoardTableSidePadding * 2
                    : defaultBoardSize;

                final landscape = constraints.biggest.aspectRatio > 1;

                final engineGaugeParams = ref.watch(
                  studyControllerProvider(id)
                      .select((state) => state.valueOrNull?.engineGaugeParams),
                );

                final currentNode = ref.watch(
                  studyControllerProvider(id)
                      .select((state) => state.requireValue.currentNode),
                );

                final gamebookActive = ref.watch(
                  studyControllerProvider(id)
                      .select((state) => state.requireValue.gamebookActive),
                );

                final engineLines = EngineLines(
                  clientEval: currentNode.eval,
                  isGameOver: currentNode.position?.isGameOver ?? false,
                  onTapMove: ref
                      .read(
                        studyControllerProvider(id).notifier,
                      )
                      .onUserMove,
                  isLandscape: landscape,
                );

                final engineGauge = engineGaugeParams != null
                    ? EngineGauge(
                        params: engineGaugeParams,
                        displayMode: landscape
                            ? EngineGaugeDisplayMode.vertical
                            : EngineGaugeDisplayMode.horizontal,
                      )
                    : null;

                return landscape
                    ? Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(
                              isTablet ? kTabletBoardTableSidePadding : 0.0,
                            ),
                            child: Row(
                              children: [
                                _StudyBoard(
                                  id: id,
                                  boardSize: boardSize,
                                  isTablet: isTablet,
                                ),
                                if (engineGauge != null) ...[
                                  const SizedBox(width: 4.0),
                                  engineGauge,
                                ],
                              ],
                            ),
                          ),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                if (engineGaugeParams != null) engineLines,
                                Expanded(
                                  child: PlatformCard(
                                    clipBehavior: Clip.hardEdge,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(4.0),
                                    ),
                                    margin: const EdgeInsets.all(
                                      kTabletBoardTableSidePadding,
                                    ),
                                    semanticContainer: false,
                                    child: StudyTreeView(id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.all(
                              isTablet ? kTabletBoardTableSidePadding : 0.0,
                            ),
                            child: Column(
                              children: [
                                if (engineGauge != null) ...[
                                  engineGauge,
                                  engineLines,
                                ],
                                _StudyBoard(
                                  id: id,
                                  boardSize: boardSize,
                                  isTablet: isTablet,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: isTablet
                                  ? const EdgeInsets.symmetric(
                                      horizontal: kTabletBoardTableSidePadding,
                                    )
                                  : EdgeInsets.zero,
                              child:
                                  gamebookActive && currentNode.position != null
                                      ? StudyGamebook(id)
                                      : StudyTreeView(id),
                            ),
                          ),
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

class _StudyBoard extends ConsumerStatefulWidget {
  const _StudyBoard({
    required this.id,
    required this.boardSize,
    required this.isTablet,
  });

  final StudyId id;

  final double boardSize;

  final bool isTablet;

  @override
  ConsumerState<_StudyBoard> createState() => _StudyBoardState();
}

class _StudyBoardState extends ConsumerState<_StudyBoard> {
  ISet<Shape> userShapes = ISet();

  @override
  Widget build(BuildContext context) {
    final boardPrefs = ref.watch(boardPreferencesProvider);
    final studyState =
        ref.watch(studyControllerProvider(widget.id)).requireValue;

    final currentNode = studyState.currentNode;
    final position = currentNode.position;

    final showVariationArrows = ref.watch(
          analysisPreferencesProvider.select(
            (prefs) => prefs.showVariationArrows,
          ),
        ) &&
        !studyState.gamebookActive &&
        currentNode.children.length > 1;

    final pgnShapes = ISet(
      studyState.pgnShapes.map((shape) => shape.chessground),
    );

    final variationArrows = ISet<Shape>(
      showVariationArrows
          ? currentNode.children.mapIndexed((i, move) {
              final color = Colors.white.withValues(alpha: i == 0 ? 0.9 : 0.5);
              return Arrow(
                color: color,
                orig: (move as NormalMove).from,
                dest: move.to,
              );
            }).toList()
          : [],
    );

    final showAnnotationsOnBoard = ref.watch(
      analysisPreferencesProvider.select((value) => value.showAnnotations),
    );

    final showBestMoveArrow = ref.watch(
      analysisPreferencesProvider.select(
        (value) => value.showBestMoveArrow,
      ),
    );
    final bestMoves = ref.watch(
      engineEvaluationProvider.select((s) => s.eval?.bestMoves),
    );
    final ISet<Shape> bestMoveShapes =
        showBestMoveArrow && studyState.isEngineAvailable && bestMoves != null
            ? computeBestMoveShapes(
                bestMoves,
                currentNode.position!.turn,
                boardPrefs.pieceSet.assets,
              )
            : ISet();

    final sanMove = currentNode.sanMove;
    final annotation = makeAnnotation(studyState.currentNode.nags);

    return Chessboard(
      size: widget.boardSize,
      settings: boardPrefs.toBoardSettings().copyWith(
            borderRadius: widget.isTablet
                ? const BorderRadius.all(Radius.circular(4.0))
                : BorderRadius.zero,
            boxShadow: widget.isTablet ? boardShadows : const <BoxShadow>[],
            drawShape: DrawShapeOptions(
              enable: true,
              onCompleteShape: _onCompleteShape,
              onClearShapes: _onClearShapes,
              newShapeColor: boardPrefs.shapeColor.color,
            ),
          ),
      fen: studyState.position?.board.fen ??
          studyState.study.currentChapterMeta.fen ??
          kInitialFEN,
      lastMove: studyState.lastMove as NormalMove?,
      orientation: studyState.pov,
      shapes: pgnShapes
          .union(userShapes)
          .union(variationArrows)
          .union(bestMoveShapes),
      annotations:
          showAnnotationsOnBoard && sanMove != null && annotation != null
              ? altCastles.containsKey(sanMove.move.uci)
                  ? IMap({
                      Move.parse(altCastles[sanMove.move.uci]!)!.to: annotation,
                    })
                  : IMap({sanMove.move.to: annotation})
              : null,
      game: position != null
          ? GameData(
              playerSide: studyState.playerSide,
              isCheck: position.isCheck,
              sideToMove: position.turn,
              validMoves: makeLegalMoves(position),
              promotionMove: studyState.promotionMove,
              onMove: (move, {isDrop, captured}) {
                ref
                    .read(studyControllerProvider(widget.id).notifier)
                    .onUserMove(move);
              },
              onPromotionSelection: (role) {
                ref
                    .read(studyControllerProvider(widget.id).notifier)
                    .onPromotionSelection(role);
              },
            )
          : null,
    );
  }

  void _onCompleteShape(Shape shape) {
    if (userShapes.any((element) => element == shape)) {
      setState(() {
        userShapes = userShapes.remove(shape);
      });
      return;
    } else {
      setState(() {
        userShapes = userShapes.add(shape);
      });
    }
  }

  void _onClearShapes() {
    setState(() {
      userShapes = ISet();
    });
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
