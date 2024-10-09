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
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
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

    final comment = studyState.gamebookComment ??
        (studyState.gamebookMoveFeedback == null
            ? 'What would you play in this position?'
            : studyState.gamebookMoveFeedback == GamebookMoveFeedback.correct
                ? 'Good move'
                : '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Column(
        children: [
          Expanded(
            child: Text(
              comment,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          GamebookFeedbackWidget(
            id: widget.id,
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
      GamebookMoveFeedback.correct => GamebookButton(
          onTap: ref.read(studyControllerProvider(id).notifier).userNext,
          icon: Icons.play_arrow,
          label: 'Next',
          highlighted: true,
        ),
      GamebookMoveFeedback.incorrect => GamebookButton(
          onTap: ref.read(studyControllerProvider(id).notifier).userPrevious,
          icon: Icons.replay,
          label: 'Retry',
          highlighted: true,
        ),
      GamebookMoveFeedback.lessonComplete => Row(
          children: [
            if (hasNextChapter)
              GamebookButton(
                icon: Icons.play_arrow,
                label: 'Next chapter',
                highlighted: true,
                onTap:
                    ref.read(studyControllerProvider(id).notifier).nextChapter,
              ),
            GamebookButton(
              onTap: ref.read(studyControllerProvider(id).notifier).reset,
              label: 'Play again',
              icon: Icons.replay,
            ),
            GamebookButton(
              onTap: () {}, // TODO
              label: 'Analysis board',
              icon: Icons.biotech,
            ),
          ],
        ),
    };
  }
}

class GamebookButton extends StatelessWidget {
  const GamebookButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  final bool highlighted;

  bool get enabled => onTap != null;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // TODO add a background?

    return Semantics(
      container: true,
      enabled: enabled,
      button: true,
      label: label,
      excludeSemantics: true,
      child: AdaptiveInkWell(
        borderRadius: BorderRadius.zero,
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: highlighted ? primary : null, size: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: highlighted ? primary : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
