import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/settings/brightness.dart';
import 'package:lichess_mobile/src/styles/lichess_colors.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_feedback_widget.dart';
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
          Text(comments),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GamebookFeedbackWidget(
                id: widget.id,
              ),
              SizedBox.square(
                dimension: 70,
                child: SvgPicture.asset(
                  'assets/images/octopus.svg',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GamebookFeedbackWidget extends ConsumerWidget {
  const GamebookFeedbackWidget({
    required this.id,
  });

  final StudyId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(
      studyControllerProvider(id)
          .select((state) => state.valueOrNull?.gamebookMoveFeedback),
    );

    final pov = ref.watch(
      studyControllerProvider(id)
          .select((state) => state.valueOrNull?.pov ?? Side.white),
    );

    final hasNextChapter = ref.watch(
      studyControllerProvider(id)
          .select((state) => state.valueOrNull?.hasNextChapter == true),
    );

    return switch (feedback) {
      null => FindTheBestMoveTile(pov: pov),
      GamebookMoveFeedback.correct => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(
              Radius.circular(4.0),
            ),
            color: LichessColors.good,
          ),
          child: const Center(
            child: Text(
              'Next',
            ),
          ),
        ),
      GamebookMoveFeedback.incorrect => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(
              Radius.circular(4.0),
            ),
            color: LichessColors.good,
          ),
          child: const Center(
            child: Text(
              'Retry',
            ),
          ),
        ),
      GamebookMoveFeedback.lessonComplete => Row(
          children: [
            if (hasNextChapter)
              FatButton(
                onPressed:
                    ref.read(studyControllerProvider(id).notifier).nextChapter,
                semanticsLabel: 'Next chapter',
                child: const Text('Next chapter'),
              ),
            FatButton(
              onPressed: () {}, // TODO
              semanticsLabel: 'Play again',
              child: const Text('Play again'),
            ),
            FatButton(
              onPressed: () {}, // TODO
              semanticsLabel: 'Analysis board',
              child: const Text('Analysis board'),
            ),
          ],
        ),
    };
  }
}
