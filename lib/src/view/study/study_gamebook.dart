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
import 'package:lichess_mobile/src/view/study/study_screen.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
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
  ConsumerState<StudyGamebook> createState() => _StudyGamebookState();
}

class _StudyGamebookState extends ConsumerState<StudyGamebook> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Comment(id: widget.id),
                    _Hint(id: widget.id),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Comment extends ConsumerWidget {
  const _Comment({
    required this.id,
  });

  final StudyId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyControllerProvider(id)).requireValue;

    final comment = state.gamebookComment ??
        switch (state.gamebookState) {
          GamebookState.findTheMove => 'What would you play in this position?',
          GamebookState.correctMove => 'Good move',
          GamebookState.incorrectMove => "That's not the move!",
          GamebookState.lessonComplete =>
            'Congratulations! You completed this lesson.',
          _ => ''
        };

    return Expanded(
      child: Scrollbar(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Text(
              comment,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends ConsumerStatefulWidget {
  const _Hint({
    required this.id,
  });

  final StudyId id;

  @override
  ConsumerState<_Hint> createState() => _HintState();
}

class _HintState extends ConsumerState<_Hint> {
  bool showHint = false;

  @override
  Widget build(BuildContext context) {
    final hint =
        ref.watch(studyControllerProvider(widget.id)).requireValue.gamebookHint;
    return hint == null
        ? const SizedBox.shrink()
        : SizedBox(
            height: 40,
            child: showHint
                ? Center(child: Text(hint))
                : TextButton(
                    onPressed: () {
                      setState(() {
                        showHint = true;
                      });
                    },
                    child: const Text('Get a hint'),
                  ),
          );
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
