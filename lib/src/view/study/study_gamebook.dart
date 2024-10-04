import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/model/study/study_controller.dart';
import 'package:lichess_mobile/src/utils/rate_limit.dart';

class StudyGamebook extends ConsumerStatefulWidget {
  const StudyGamebook(
    this.id,
  );

  final StudyId id;

  @override
  ConsumerState<StudyGamebook> createState() => _StudyTreeViewState();
}

class _StudyTreeViewState extends ConsumerState<StudyGamebook> {
  @override
  Widget build(BuildContext context) {
    final studyState =
        ref.watch(studyControllerProvider(widget.id)).valueOrNull;

    if (studyState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentNode = studyState.currentNode;

    final currentNodeComments =
        (currentNode.isRoot ? studyState.pgnRootComments : currentNode.comments)
                ?.map((comment) => comment.text)
                .nonNulls
                .join('\n') ??
            '';

    final comments = currentNodeComments.isNotEmpty
        ? currentNodeComments
        : studyState.gamebookMoveFeedback == null
            ? 'What would you play in this position?'
            : studyState.gamebookMoveFeedback == GamebookMoveFeedback.correct
                ? 'Good move'
                : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                comments,
                style: const TextStyle(
                  fontSize: 16.0,
                ),
              ),
            ),
          ),
          if (studyState.gamebookMoveFeedback == GamebookMoveFeedback.correct &&
              !studyState.isAtEndOfChapter)
            FatButton(
              onPressed: () {
                ref
                    .read(studyControllerProvider(widget.id).notifier)
                    .userNext();
              },
              //icon: const Icon(Icons.play_arrow),
              semanticsLabel: 'Next', // TODO l10n
              child: const Text('Next'), // TODO l10n
            ),
          if (studyState.gamebookMoveFeedback == GamebookMoveFeedback.incorrect)
            FatButton(
              onPressed: () {
                ref
                    .read(studyControllerProvider(widget.id).notifier)
                    .userPrevious();
              },
              //icon: const Icon(Icons.play_arrow),
              semanticsLabel: 'Retry', // TODO l10n
              child: const Text('Retry'), // TODO l10n
            ),
          // TODO potentially move these to bottom bar
          if (studyState.isAtEndOfChapter)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (!currentNode.isRoot)
                  SecondaryButton(
                    onPressed: () {},
                    semanticsLabel: 'Play again', // TODO l10n
                    //icon: const Icon(Icons.restart_alt),
                    child: const Text('Play again'), // TODO l10n
                  ),
                if (studyState.hasNextChapter)
                  FatButton(
                    onPressed: () {
                      ref
                          .read(studyControllerProvider(widget.id).notifier)
                          .nextChapter();
                    },
                    //icon: const Icon(Icons.play_arrow),
                    semanticsLabel: 'Next Chapter', // TODO l10n
                    child: const Text('Next Chapter'), // TODO l10n
                  ),
                if (!currentNode.isRoot)
                  SecondaryButton(
                    onPressed: () {},
                    semanticsLabel: 'Analysis board', // TODO l10n
                    //icon: const Icon(Icons.biotech),
                    child: const Text('Analysis board'), // TODO l10n
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
