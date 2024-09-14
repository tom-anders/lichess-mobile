import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/account/account_preferences.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_preferences.dart';
import 'package:lichess_mobile/src/model/analysis/opening_service.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/node.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/model/study/study_analysis.dart';
import 'package:lichess_mobile/src/model/study/study_controller.dart';
import 'package:lichess_mobile/src/model/study/study_node.dart';
import 'package:lichess_mobile/src/utils/duration.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/rate_limit.dart';
import 'package:lichess_mobile/src/view/analysis/annotations.dart';
import 'package:lichess_mobile/src/view/study/study_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/list.dart';

// fast replay debounce delay, same as piece animation duration, to avoid piece
// animation jank at the end of the replay
const kFastReplayDebounceDelay = Duration(milliseconds: 150);
const kOpeningHeaderHeight = 32.0;
const kInlineMoveSpacing = 3.0;

class StudyTreeView extends ConsumerStatefulWidget {
  const StudyTreeView(
    this.id,
  );

  final StudyId id;

  @override
  ConsumerState<StudyTreeView> createState() => _StudyTreeViewState();
}

class _StudyTreeViewState extends ConsumerState<StudyTreeView> {
  final currentMoveKey = GlobalKey();
  final _debounce = Debouncer(kFastReplayDebounceDelay);
  late StudyNode currentNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentMoveKey.currentContext != null) {
        Scrollable.ensureVisible(
          currentMoveKey.currentContext!,
          alignment: 0.5,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
    currentNode = ref.read(
      studyControllerProvider(widget.id).select(
        (value) => value.requireValue.currentNode,
      ),
    );
  }

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }

  // This is the most expensive part of the study tree view because of the tree
  // that may be very large.
  // Great care must be taken to avoid unnecessary rebuilds.
  // This should actually rebuild only when the current path changes or a new node
  // is added.
  // Debouncing the current path change is necessary to avoid rebuilding when
  // using the fast replay buttons.
  @override
  Widget build(BuildContext context) {
    ref.listen(
      studyControllerProvider(widget.id),
      (prev, state) {
        //if (prev?.currentPath != state.currentPath) {
        //  // debouncing the current path change to avoid rebuilding when using
        //  // the fast replay buttons
        //  _debounce(() {
        //    setState(() {
        //      currentPath = state.currentPath;
        //    });
        //    WidgetsBinding.instance.addPostFrameCallback((_) {
        //      if (currentMoveKey.currentContext != null) {
        //        Scrollable.ensureVisible(
        //          currentMoveKey.currentContext!,
        //          duration: const Duration(milliseconds: 200),
        //          curve: Curves.easeIn,
        //          alignment: 0.5,
        //          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        //        );
        //      }
        //    });
        //  });
        //}
      },
    );

    final root = ref.watch(
      studyControllerProvider(widget.id).select(
        (value) => value.maybeWhen(
          data: (data) => data.tree,
          orElse: () => null,
        ),
      ),
    );

    final moveWidgets = root != null
        ? [
            if (root.comments != null) _Comments(root.comments!),
            _buildMainline(root),
          ]
        : <Widget>[];

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              //spacing: kInlineMoveSpacing,
              children: moveWidgets,
            ),
          ),
        ),
      ],
    );
  }
}

/// True if the side line has no branching and is less than 6 moves deep.
bool displaySideLineAsInline(StudyBranch node, [int depth = 6]) {
  assert(depth >= 0);
  if (depth == 0) return true;
  if (node.children.isEmpty) return true;
  if (node.children.length > 1) return true;
  return displaySideLineAsInline(node.children.first, depth - 1);
}

List<InlineSpan> _buildInlineSideLine({required StudyBranch sideLineStart}) {
  return [
    const TextSpan(text: '('),
    ...[sideLineStart]
        .followedBy(sideLineStart.mainline)
        .mapIndexedAndLast(
          (i, node, isLast) => moveWithComment(
            node: node,
            // TODO
            isCurrentMove: false,
            isSideline: true,
            startMainline: false,
            startSideline: i == 0,
          ),
        )
        .flattened,
    const TextSpan(text: ')'),
  ];
}

List<InlineSpan> moveWithComment({
  required StudyBranch node,
  required bool isCurrentMove,
  required bool isSideline,
  required bool startMainline,
  required bool startSideline,
}) =>
    [
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: InlineMove(
          node: node,
          isCurrentMove: isCurrentMove,
          isSideline: isSideline,
          startMainline: startMainline,
          startSideline: startSideline,
          onTap: () => {
            // TODO
          },
        ),
      ),
      // TODO adjust text style if sideline
      if (node.comments != null)
        ...node.comments!.map((comment) => TextSpan(text: comment.text)),
    ];

List<InlineSpan> _buildSideLine({
  required StudyBranch sideLineStart,
}) {
  return [TextSpan(text: 'sideline! ${sideLineStart.sanMove}')];
}

// TODO make this a stateless widget?
Widget _buildMainline(StudyRoot root) {
  if (root.children.isEmpty) return const SizedBox.shrink();

  final lines = [root, ...root.mainline].map((node) => node.children).fold(
    [<InlineSpan>[]],
    (lines, children) {
      if (children.isNotEmpty) {
        final (mainlineNode, sideLineNodes) =
            (children.first, children.skip(1));

        lines.last.addAll([
          // mainline move
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InlineMove(
              node: mainlineNode,
              isCurrentMove: false,
              isSideline: false,
              startMainline: lines.last.isEmpty,
              startSideline: false,
              onTap: () => {
                // TODO
              },
            ),
          ),
          if (mainlineNode.comments != null)
            ...mainlineNode.comments!
                .map((comment) => TextSpan(text: comment.text)),
        ]);

        if (sideLineNodes.isNotEmpty) {
          if (sideLineNodes.length == 1 &&
              displaySideLineAsInline(sideLineNodes.first)) {
            lines.last.addAll(
              _buildInlineSideLine(sideLineStart: sideLineNodes.first),
            );
          } else {
            // Add sideline(s) on their own line
            lines.addAll(
              sideLineNodes
                  .map((sideline) => _buildSideLine(sideLineStart: sideline)),
            );

            // Continue the mainline on a new line
            lines.add([]);
          }
        }
      }

      return lines;
    },
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: lines.map((line) {
      return Text.rich(
        TextSpan(
          children: line,
        ),
      );
    }).toList(),
  );
}

Color? _textColor(
  BuildContext context,
  double opacity, {
  int? nag,
}) {
  final defaultColor = Theme.of(context).platform == TargetPlatform.android
      ? Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(opacity)
      : CupertinoTheme.of(context)
          .textTheme
          .textStyle
          .color
          ?.withOpacity(opacity);

  return nag != null && nag > 0 ? nagColor(nag) : defaultColor;
}

class InlineMove extends ConsumerWidget {
  const InlineMove({
    required this.node,
    required this.isCurrentMove,
    required this.isSideline,
    super.key,
    this.startMainline = false,
    this.startSideline = false,
    this.onTap,
    this.onLongPress,
  });

  final StudyBranch node;
  final bool isCurrentMove;
  final bool isSideline;
  final bool startMainline;
  final bool startSideline;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const borderRadius = BorderRadius.all(Radius.circular(4.0));
  static const baseTextStyle = TextStyle(
    fontSize: 16.0,
    height: 1.5,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pieceNotation = ref.watch(pieceNotationProvider).maybeWhen(
          data: (value) => value,
          orElse: () => defaultAccountPreferences.pieceNotation,
        );
    final fontFamily =
        pieceNotation == PieceNotation.symbol ? 'ChessFont' : null;

    final textStyle = isSideline
        ? TextStyle(
            fontFamily: fontFamily,
            color: _textColor(context, 0.6),
          )
        : baseTextStyle.copyWith(
            fontFamily: fontFamily,
            color: _textColor(context, 0.9),
            fontWeight: FontWeight.w600,
          );

    final indexTextStyle = baseTextStyle.copyWith(
      color: _textColor(context, 0.6),
    );

    final indexWidget = node.ply.isOdd
        ? Text(
            '${(node.ply / 2).ceil()}.',
            style: indexTextStyle,
          )
        : ((startMainline || startSideline)
            ? Text(
                '${(node.ply / 2).ceil()}...',
                style: indexTextStyle,
              )
            : null);

    final moveWithNag = node.sanMove +
        (node.nags != null ? moveAnnotationChar(node.nags!) : '');

    return Text.rich(
      TextSpan(
        children: [
          if (indexWidget != null) WidgetSpan(child: indexWidget),
          if (indexWidget != null) WidgetSpan(child: const SizedBox(width: 1)),
          WidgetSpan(
            child: AdaptiveInkWell(
              borderRadius: borderRadius,
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                decoration: isCurrentMove
                    ? BoxDecoration(
                        color: Theme.of(context).platform == TargetPlatform.iOS
                            ? CupertinoColors.systemGrey3.resolveFrom(context)
                            : Theme.of(context).focusColor,
                        shape: BoxShape.rectangle,
                        borderRadius: borderRadius,
                      )
                    : null,
                child: Text(
                  moveWithNag,
                  style: isCurrentMove
                      ? textStyle.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _textColor(
                            context,
                            1,
                            nag: node.nags?.firstOrNull,
                          ),
                        )
                      : textStyle.copyWith(
                          color: _textColor(
                            context,
                            0.9,
                            nag: node.nags?.firstOrNull,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Comments extends StatelessWidget {
  const _Comments(this.comments, {this.isSideline = false});

  final Iterable<StudyNodeComment> comments;
  final bool isSideline;

  @override
  Widget build(BuildContext context) {
    return AdaptiveInkWell(
      child: Text(
        comments.map((comment) => comment.text).join('\n'),
        style: TextStyle(
          color:
              isSideline ? _textColor(context, 0.6) : _textColor(context, 0.7),
        ),
      ),
    );
  }
}
