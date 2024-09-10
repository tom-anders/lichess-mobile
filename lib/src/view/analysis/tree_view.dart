import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/account/account_preferences.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_preferences.dart';
import 'package:lichess_mobile/src/model/analysis/opening_service.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/node.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/utils/duration.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/rate_limit.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/pgn_tree_view.dart';

import 'annotations.dart';

// fast replay debounce delay, same as piece animation duration, to avoid piece
// animation jank at the end of the replay
const kFastReplayDebounceDelay = Duration(milliseconds: 150);
const kOpeningHeaderHeight = 32.0;
const kInlineMoveSpacing = 3.0;

class AnalysisTreeView extends ConsumerStatefulWidget {
  const AnalysisTreeView(
    this.pgn,
    this.options,
    this.displayMode,
  );

  final String pgn;
  final AnalysisOptions options;
  final Orientation displayMode;

  @override
  ConsumerState<AnalysisTreeView> createState() => _InlineTreeViewState();
}

class _InlineTreeViewState extends ConsumerState<AnalysisTreeView> {
  final currentMoveKey = GlobalKey();
  final _debounce = Debouncer(kFastReplayDebounceDelay);
  late UciPath currentPath;

  @override
  void initState() {
    super.initState();
    currentPath = ref.read(
      analysisControllerProvider(widget.pgn, widget.options).select(
        (value) => value.currentPath,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentMoveKey.currentContext != null) {
        Scrollable.ensureVisible(
          currentMoveKey.currentContext!,
          alignment: 0.5,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  @override
  void dispose() {
    _debounce.dispose();
    super.dispose();
  }

  // This is the most expensive part of the analysis view because of the tree
  // that may be very large.
  // Great care must be taken to avoid unnecessary rebuilds.
  // This should actually rebuild only when the current path changes or a new node
  // is added.
  // Debouncing the current path change is necessary to avoid rebuilding when
  // using the fast replay buttons.
  @override
  Widget build(BuildContext context) {
    ref.listen(
      analysisControllerProvider(widget.pgn, widget.options),
      (prev, state) {
        if (prev?.currentPath != state.currentPath) {
          // debouncing the current path change to avoid rebuilding when using
          // the fast replay buttons
          _debounce(() {
            setState(() {
              currentPath = state.currentPath;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (currentMoveKey.currentContext != null) {
                Scrollable.ensureVisible(
                  currentMoveKey.currentContext!,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeIn,
                  alignment: 0.5,
                  alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
                );
              }
            });
          });
        }
      },
    );

    final ctrlProvider = analysisControllerProvider(widget.pgn, widget.options);
    final root = ref.watch(ctrlProvider.select((value) => value.root));
    final rootComments = ref.watch(
      ctrlProvider.select((value) => value.pgnRootComments),
    );

    final shouldShowComments = ref.watch(
      analysisPreferencesProvider.select((value) => value.showPgnComments),
    );

    final shouldShowAnnotations = ref.watch(
      analysisPreferencesProvider.select((value) => value.showAnnotations),
    );

    return CustomScrollView(
      slivers: [
        if (kOpeningAllowedVariants.contains(widget.options.variant))
          SliverPersistentHeader(
            delegate: _OpeningHeaderDelegate(
              ctrlProvider,
              displayMode: widget.displayMode,
            ),
          ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: PgnTreeView(

            root: root,
            rootComments: rootComments,
            params: (
              shouldShowAnnotations: shouldShowAnnotations,
              shouldShowComments: shouldShowComments,
              currentMoveKey: currentMoveKey,
              currentPath: currentPath,
              notifier: () => ref.read(ctrlProvider.notifier),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpeningHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _OpeningHeaderDelegate(
    this.ctrlProvider, {
    required this.displayMode,
  });

  final AnalysisControllerProvider ctrlProvider;
  final Orientation displayMode;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _Opening(ctrlProvider, displayMode);
  }

  @override
  double get minExtent => kOpeningHeaderHeight;

  @override
  double get maxExtent => kOpeningHeaderHeight;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

class _Opening extends ConsumerWidget {
  const _Opening(this.ctrlProvider, this.displayMode);

  final AnalysisControllerProvider ctrlProvider;
  final Orientation displayMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRootNode = ref.watch(
      ctrlProvider.select((s) => s.currentNode.isRoot),
    );
    final nodeOpening =
        ref.watch(ctrlProvider.select((s) => s.currentNode.opening));
    final branchOpening =
        ref.watch(ctrlProvider.select((s) => s.currentBranchOpening));
    final contextOpening =
        ref.watch(ctrlProvider.select((s) => s.contextOpening));
    final opening = isRootNode
        ? LightOpening(
            eco: '',
            name: context.l10n.startPosition,
          )
        : nodeOpening ?? branchOpening ?? contextOpening;

    return opening != null
        ? Container(
            height: kOpeningHeaderHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  opening.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}
