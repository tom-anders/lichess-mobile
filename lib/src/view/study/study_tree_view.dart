import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/model/study/study_controller.dart';
import 'package:lichess_mobile/src/utils/rate_limit.dart';
import 'package:lichess_mobile/src/widgets/pgn_tree_view.dart';

// fast replay debounce delay, same as piece animation duration, to avoid piece
// animation jank at the end of the replay
const kFastReplayDebounceDelay = Duration(milliseconds: 150);
const kNextChapterButtonHeight = 32.0;
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
  late UciPath currentPath;

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
    currentPath = ref.read(
      studyControllerProvider(widget.id).select(
        (value) => value.requireValue.currentPath,
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
        if (state.hasValue &&
            prev?.valueOrNull?.currentPath != state.requireValue.currentPath) {
          // debouncing the current path change to avoid rebuilding when using
          // the fast replay buttons
          _debounce(() {
            setState(() {
              currentPath = state.requireValue.currentPath;
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

    final studyState = ref.watch(studyControllerProvider(widget.id));

    if (!studyState.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final root = studyState.requireValue.root;
    final rootComments = studyState.requireValue.pgnRootComments;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              Expanded(
                child: PgnTreeView(
                  root: root,
                  rootComments: rootComments,
                  params: (
                    shouldShowComments: true,
                    shouldShowAnnotations: true,
                    currentPath: currentPath,
                    notifier: () =>
                        ref.read(studyControllerProvider(widget.id).notifier),
                    currentMoveKey: currentMoveKey,
                  ),
                ),
              ),
              Container(
                height: 32.0,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                ),
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(studyControllerProvider(widget.id).notifier)
                        .nextChapter();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              child: Icon(Icons.play_arrow),
                              alignment: PlaceholderAlignment.middle,
                            ),
                            TextSpan(text: 'Next chapter'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
