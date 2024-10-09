import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/study/study_controller.dart';
import 'package:lichess_mobile/src/view/analysis/tree_view.dart';

const kNextChapterButtonHeight = 32.0;

class StudyTreeView extends ConsumerWidget {
  const StudyTreeView(
    this.id,
  );

  final StudyId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = ref.watch(
      studyControllerProvider(id).select((value) => value.requireValue.root),
    );

    final currentPath = ref.watch(
      studyControllerProvider(id)
          .select((value) => value.requireValue.currentPath),
    );

    final pgnRootComments = ref.watch(
      studyControllerProvider(id)
          .select((value) => value.requireValue.pgnRootComments),
    );

    final hasNextChapter = ref.watch(
      studyControllerProvider(id)
          .select((value) => value.requireValue.hasNextChapter),
    );

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (root != null)
                Expanded(
                  child: DebouncedPgnTreeView(
                    root: root,
                    currentPath: currentPath,
                    pgnRootComments: pgnRootComments,
                    notifier: ref.read(studyControllerProvider(id).notifier),
                  ),
                )
              else
                const Spacer(),
              if (hasNextChapter)
                Container(
                  height: 32.0,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      ref
                          .read(studyControllerProvider(id).notifier)
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
