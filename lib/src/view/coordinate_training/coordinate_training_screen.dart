import 'dart:async';
import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/coordinate_training/coordinate_training_controller.dart';
import 'package:lichess_mobile/src/model/coordinate_training/coordinate_training_preferences.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/styles/lichess_colors.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/view/coordinate_training/coordinate_display.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';

Future<void> _coordinateTrainingInfoDialogBuilder(BuildContext context) {
  return showAdaptiveDialog(
    context: context,
    builder: (context) {
      final content = SingleChildScrollView(
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: const [
              TextSpan(
                text: '\n',
              ),
              TextSpan(
                text: 'TODO Add info here once translations can be downloaded',
              ),
            ],
          ),
        ),
      );
      return Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoAlertDialog(
              title: Text(context.l10n.aboutX('Coordinate Training')),
              content: content,
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.mobileOkButton),
                ),
              ],
            )
          : AlertDialog(
              title: Text(context.l10n.aboutX('Coordinate Training')),
              content: content,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.mobileOkButton),
                ),
              ],
            );
    },
  );
}

class CoordinateTrainingScreen extends StatelessWidget {
  const CoordinateTrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformWidget(
      androidBuilder: _androidBuilder,
      iosBuilder: _iosBuilder,
    );
  }

  Widget _androidBuilder(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coordinate Training'),
      ),
      body: const _Body(),
    );
  }

  Widget _iosBuilder(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Styles.cupertinoScaffoldColor.resolveFrom(context),
        border: null,
        middle: const Text('Coordinate Training'),
      ),
      child: const _Body(),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late Side orientation;

  IMap<Square, SquareHighlight> highlightLastGuess = const IMap.empty();

  bool lastGuessWasCorrect = true;

  Timer? highlightTimer;

  void _setOrientation(SideChoice choice) {
    setState(() {
      orientation = switch (choice) {
        SideChoice.white => Side.white,
        SideChoice.black => Side.black,
        SideChoice.random => Side.values[Random().nextInt(Side.values.length)],
      };
    });
  }

  @override
  void initState() {
    super.initState();
    _setOrientation(ref.read(coordinateTrainingPreferencesProvider).sideChoice);
  }

  @override
  Widget build(BuildContext context) {
    final trainingController = ref.watch(coordinateTrainingControllerProvider);
    final trainingNotifier =
        ref.watch(coordinateTrainingControllerProvider.notifier);
    final trainingPrefs = ref.watch(coordinateTrainingPreferencesProvider);

    final IMap<Square, SquareHighlight> squareHighlights =
        trainingController.trainingActive
            ? trainingPrefs.mode == TrainingMode.findSquare
                ? highlightLastGuess
                : {
                    trainingController.currentCoord!: SquareHighlight(
                      details: HighlightDetails(
                        solidColor: LichessColors.good.withOpacity(
                          0.5,
                        ),
                      ),
                    ),
                  }.lock
            : const IMap.empty();

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final aspectRatio = constraints.biggest.aspectRatio;

                final defaultBoardSize = constraints.biggest.shortestSide;
                final isTablet = isTabletOrLarger(context);
                final remainingHeight =
                    constraints.maxHeight - defaultBoardSize;
                final isSmallScreen =
                    remainingHeight < kSmallRemainingHeightLeftBoardThreshold;
                final boardSize = isTablet || isSmallScreen
                    ? defaultBoardSize - kTabletBoardTableSidePadding * 2
                    : defaultBoardSize;

                final direction =
                    aspectRatio > 1 ? Axis.horizontal : Axis.vertical;

                return Flex(
                  direction: direction,
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: boardSize *
                                (trainingController.timePercentageElapsed ??
                                    0.0),
                            height: 15.0,
                            child: ColoredBox(
                              color: lastGuessWasCorrect
                                  ? LichessColors.good
                                  : LichessColors.error,
                            ),
                          ),
                        ),
                        _TrainingBoard(
                          boardSize: boardSize,
                          isTablet: isTablet,
                          orientation: orientation,
                          squareHighlights: squareHighlights,
                          onGuess: (square) {
                            if (trainingController.trainingActive) {
                              final correct =
                                  trainingNotifier.onGuessCoord(square);

                              setState(() {
                                lastGuessWasCorrect = correct;
                                highlightLastGuess = {
                                  square: SquareHighlight(
                                    details: HighlightDetails(
                                      solidColor: correct
                                          ? LichessColors.good
                                          : LichessColors.error,
                                    ),
                                  ),
                                }.lock;

                                highlightTimer = Timer(
                                    const Duration(milliseconds: 200), () {
                                  setState(() {
                                    highlightLastGuess = const IMap.empty();
                                  });
                                });
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    if (trainingController.trainingActive)
                      Expanded(
                        child: Center(
                          child: _Score(
                            size: boardSize / 8,
                            color: lastGuessWasCorrect
                                ? LichessColors.good
                                : LichessColors.error,
                          ),
                        ),
                      )
                    else
                      _Settings(
                        onSideChoiceSelected: _setOrientation,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const _BottomBar(),
      ],
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoDynamicColor.resolve(
              CupertinoColors.tertiarySystemGroupedBackground,
              context,
            )
          : Theme.of(context).bottomAppBarTheme.color,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kBottomBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: BottomBarButton(
                  label: context.l10n.menu,
                  onTap: () => showAdaptiveBottomSheet<void>(
                    context: context,
                    builder: (BuildContext context) =>
                        const _CoordinateTrainingMenu(),
                  ),
                  icon: Icons.tune,
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  icon: Icons.info_outline,
                  label: context.l10n.aboutX('Coorinate Training'),
                  onTap: () => _coordinateTrainingInfoDialogBuilder(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoordinateTrainingMenu extends ConsumerWidget {
  const _CoordinateTrainingMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingPrefs = ref.watch(coordinateTrainingPreferencesProvider);
    final trainingPrefsNotifier =
        ref.watch(coordinateTrainingPreferencesProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ListSection(
                header: Text(
                  context.l10n.preferencesDisplay,
                  style: Styles.sectionTitle,
                ),
                children: [
                  SwitchSettingTile(
                    title: const Text('Show Coordinates'),
                    value: trainingPrefs.showCoordinates,
                    onChanged: trainingPrefsNotifier.setShowCoordinates,
                  ),
                  SwitchSettingTile(
                    title: const Text('Show Pieces'),
                    value: trainingPrefs.showPieces,
                    onChanged: trainingPrefsNotifier.setShowPieces,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Score extends ConsumerWidget {
  const _Score({
    required this.size,
    required this.color,
  });

  final double size;

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingController = ref.watch(coordinateTrainingControllerProvider);
    return Padding(
      padding: const EdgeInsets.only(
        top: 10.0,
        left: 10.0,
        right: 10.0,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(
            Radius.circular(4.0),
          ),
          color: color,
        ),
        width: size,
        height: size,
        child: Center(
          child: Text(
            trainingController.score.toString(),
            style: Styles.bold.copyWith(
              color: Colors.white,
              fontSize: 24.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _Settings extends ConsumerStatefulWidget {
  const _Settings({
    required this.onSideChoiceSelected,
  });

  final void Function(SideChoice) onSideChoiceSelected;

  @override
  ConsumerState<_Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<_Settings> {
  @override
  Widget build(BuildContext context) {
    final trainingPrefs = ref.watch(coordinateTrainingPreferencesProvider);
    final trainingPrefsNotifier =
        ref.read(coordinateTrainingPreferencesProvider.notifier);
    final trainingNotifier =
        ref.watch(coordinateTrainingControllerProvider.notifier);

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          PlatformListTile(
            title: Text(context.l10n.side),
            trailing: Padding(
              padding: Styles.horizontalBodyPadding,
              child: Wrap(
                spacing: 8.0,
                children: SideChoice.values.map((choice) {
                  return ChoiceChip(
                    label: Text(sideChoiceL10n(context, choice)),
                    selected: trainingPrefs.sideChoice == choice,
                    showCheckmark: false,
                    onSelected: (selected) {
                      widget.onSideChoiceSelected(choice);
                      trainingPrefsNotifier.setSideChoice(choice);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          PlatformListTile(
            title: Text(context.l10n.time),
            trailing: Padding(
              padding: Styles.horizontalBodyPadding,
              child: Wrap(
                spacing: 8.0,
                children: TimeChoice.values.map((choice) {
                  return ChoiceChip(
                    label: timeChoiceL10n(context, choice),
                    selected: trainingPrefs.timeChoice == choice,
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        trainingPrefsNotifier.setTimeChoice(choice);
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          // TODO comment this in once mode "Name Square" mode is implemented
          //PlatformListTile(
          //  title: Text(context.l10n.mode),
          //  trailing: Padding(
          //    padding: Styles.horizontalBodyPadding,
          //    child: Wrap(
          //      spacing: 8.0,
          //      children: TrainingMode.values.map((mode) {
          //        return ChoiceChip(
          //          label: Text(trainingModeL10n(context, mode)),
          //          selected: trainingPrefs.mode == mode,
          //          showCheckmark: false,
          //          onSelected: (selected) {
          //            if (selected) {
          //              trainingPrefsNotifier.setMode(mode);
          //            }
          //          },
          //        );
          //      }).toList(),
          //    ),
          //  ),
          //),
          FatButton(
            semanticsLabel: 'Start Training',
            onPressed: () => trainingNotifier
                .startTraining(trainingPrefs.timeChoice.duration),
            child: const Text(
              // TODO l10n once script works
              'Start Training',
              style: Styles.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingBoard extends ConsumerStatefulWidget {
  const _TrainingBoard({
    required this.boardSize,
    required this.isTablet,
    required this.orientation,
    required this.onGuess,
    required this.squareHighlights,
  });

  final double boardSize;

  final bool isTablet;

  final Side orientation;

  final void Function(Square) onGuess;

  final IMap<Square, SquareHighlight> squareHighlights;

  @override
  ConsumerState<_TrainingBoard> createState() => _TrainingBoardState();
}

class _TrainingBoardState extends ConsumerState<_TrainingBoard> {
  @override
  Widget build(BuildContext context) {
    final boardPrefs = ref.watch(boardPreferencesProvider);
    final trainingPrefs = ref.watch(coordinateTrainingPreferencesProvider);
    final trainingController = ref.watch(coordinateTrainingControllerProvider);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ChessboardEditor(
              size: widget.boardSize,
              pieces: readFen(
                trainingPrefs.showPieces ? kInitialFEN : kEmptyFEN,
              ),
              squareHighlights: widget.squareHighlights,
              orientation: widget.orientation,
              settings: ChessboardEditorSettings(
                pieceAssets: boardPrefs.pieceSet.assets,
                colorScheme: boardPrefs.boardTheme.colors,
                enableCoordinates: trainingPrefs.showCoordinates,
                borderRadius: widget.isTablet
                    ? const BorderRadius.all(Radius.circular(4.0))
                    : BorderRadius.zero,
                boxShadow: widget.isTablet ? boardShadows : const <BoxShadow>[],
              ),
              pointerMode: EditorPointerMode.edit,
              onEditedSquare: (square) {
                if (trainingController.trainingActive &&
                    trainingPrefs.mode == TrainingMode.findSquare) {
                  widget.onGuess(square);
                }
              },
            ),
            if (trainingController.trainingActive &&
                trainingPrefs.mode == TrainingMode.findSquare)
              CoordinateDisplay(
                currentCoord: trainingController.currentCoord!,
                nextCoord: trainingController.nextCoord!,
              ),
          ],
        ),
      ],
    );
  }
}
