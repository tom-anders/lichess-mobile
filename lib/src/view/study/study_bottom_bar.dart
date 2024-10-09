import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
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
import 'package:lichess_mobile/src/widgets/list.dart';

class StudyBottomBar extends ConsumerWidget {
  const StudyBottomBar({
    required this.id,
  });

  final StudyId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyControllerProvider(id)).valueOrNull;
    if (state == null) {
      return const BottomBar(children: []);
    }

    final onGoForward = state.canGoNext
        ? ref.read(studyControllerProvider(id).notifier).userNext
        : null;
    final onGoBack = state.canGoBack
        ? ref.read(studyControllerProvider(id).notifier).userPrevious
        : null;

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
                        final chapter = state.study.chapters[index];
                        final selected = chapter.id == state.currentChapter.id;
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
                            ref
                                .read(studyControllerProvider(id).notifier)
                                .goToChapter(
                                  chapter.id,
                                );
                            Navigator.of(context).pop();
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const PlatformDivider(
                        height: 1,
                      ),
                      itemCount: state.study.chapters.length,
                    ),
                  ),
                ],
              );
            },
          ),
          showTooltip: false,
        ),
        if (state.gamebookActive) ...[
          BottomBarButton(
            onTap: state.isAtStartOfChapter
                ? null
                : ref.read(studyControllerProvider(id).notifier).reset,
            label: 'Play again',
            icon: Icons.replay,
          ),
          if (state.isAtEndOfChapter)
            BottomBarButton(
              label: 'Analysis Board',
              icon: Icons.biotech,
              onTap: () {}, // TODO open pgn in analysiscreen
            ),
        ] else ...[
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
      ],
    );
  }
}
