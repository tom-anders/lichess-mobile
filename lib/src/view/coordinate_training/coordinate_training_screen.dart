import 'package:chessground/chessground.dart' as cg;
import 'package:dartchess/dartchess.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/coordinate_training/coordinate_training_controller.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/styles/lichess_colors.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
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

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingController = ref.watch(coordinateTrainingControllerProvider);

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
                    _TrainingBoard(
                      boardSize: boardSize,
                      isTablet: isTablet,
                    ),
                    if (trainingController.inTraining)
                      Expanded(
                        child: Center(
                          child: _Score(size: boardSize / 8),
                        ),
                      )
                    else
                      const _Settings(),
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
    final trainingNotifier =
        ref.watch(coordinateTrainingControllerProvider.notifier);
    final trainingController = ref.watch(coordinateTrainingControllerProvider);

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
                    value: trainingController.showCoordinates,
                    onChanged: trainingNotifier.setShowCoordinates,
                  ),
                  SwitchSettingTile(
                    title: const Text('Show Pieces'),
                    value: trainingController.showPieces,
                    onChanged: trainingNotifier.setShowPieces,
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
  final double size;

  const _Score({
    required this.size,
  });

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
          color: trainingController.lastGuessWasMistake
              ? LichessColors.error
              : LichessColors.good,
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
  const _Settings();

  @override
  ConsumerState<_Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<_Settings> {
  SideChoice sideChoice = SideChoice.random;

  TimeChoice timeChoice = TimeChoice.thirtySeconds;

  @override
  Widget build(BuildContext context) {
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
                    selected: sideChoice == choice,
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() {
                        sideChoice = choice;
                        trainingNotifier.setSideChoice(choice);
                      });
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
                    selected: timeChoice == choice,
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() {
                        timeChoice = choice;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          FatButton(
            semanticsLabel: 'Start Training',
            onPressed: () =>
                trainingNotifier.startTraining(timeChoice.duration),
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

class _TrainingBoard extends ConsumerWidget {
  final double boardSize;

  final bool isTablet;
  const _TrainingBoard({
    required this.boardSize,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardPrefs = ref.watch(boardPreferencesProvider);
    final trainingController = ref.watch(coordinateTrainingControllerProvider);
    final trainingNotifier =
        ref.watch(coordinateTrainingControllerProvider.notifier);

    return Column(
      children: [
        Align(
          alignment: Alignment.center,
          child: SizedBox(
            width:
                boardSize * (trainingController.timePercentageElapsed ?? 0.0),
            height: 15.0,
            child: ColoredBox(
              color: trainingController.lastGuessWasMistake
                  ? LichessColors.error
                  : LichessColors.good,
            ),
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            cg.ChessboardEditor(
              size: boardSize,
              pieces: cg.readFen(
                trainingController.showPieces ? kInitialFEN : kEmptyFEN,
              ),
              orientation: trainingController.orientation,
              settings: cg.ChessboardEditorSettings(
                pieceAssets: boardPrefs.pieceSet.assets,
                colorScheme: boardPrefs.boardTheme.colors,
                enableCoordinates: trainingController.showCoordinates,
                borderRadius: isTablet
                    ? const BorderRadius.all(Radius.circular(4.0))
                    : BorderRadius.zero,
                boxShadow: isTablet ? boardShadows : const <BoxShadow>[],
              ),
              pointerMode: cg.EditorPointerMode.edit,
              onEditedSquare: trainingNotifier.onTappedCoord,
            ),
            if (trainingController.inTraining)
              _CoordinateDisplay(
                currentCoord: trainingController.currentCoord!,
                nextCoord: trainingController.nextCoord!,
              ),
          ],
        ),
      ],
    );
  }
}

class _CoordinateDisplay extends ConsumerStatefulWidget {
  const _CoordinateDisplay({
    required this.currentCoord,
    required this.nextCoord,
  });

  final Square currentCoord;
  final Square nextCoord;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _CoordinateDisplayState();
}

class _CoordinateDisplayState extends ConsumerState<_CoordinateDisplay>
    with SingleTickerProviderStateMixin {
  static const Offset kNextCoordFractionalTranslation = Offset(1, 0);
  static const double kNextCoordScale = 0.8;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..value = 1.0;

  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: kNextCoordScale,
    end: 1.0,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.linear),
  );

  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: kNextCoordFractionalTranslation,
    end: Offset.zero,
  ).animate(
    CurvedAnimation(parent: _controller, curve: Curves.linear),
  );

  @override
  void didUpdateWidget(covariant _CoordinateDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.nextCoord != widget.nextCoord) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trainingController = ref.watch(coordinateTrainingControllerProvider);

    final coordShadow = [
      const Shadow(
        color: Colors.black,
        offset: Offset(0, 5),
        blurRadius: 40.0,
      ),
    ];

    return IgnorePointer(
      child: Opacity(
        opacity: 0.8,
        child: Stack(
          children: [
            SlideTransition(
              position: _slideAnimation,
              //child: ScaleTransition(
              //  scale: _scaleAnimation,
              child: Text(
                trainingController.currentCoord?.name ?? '',
                style: DefaultTextStyle.of(context).style.copyWith(
                      fontSize: 150.0,
                      color: trainingController.recentMistake
                          ? LichessColors.error
                          : null,
                      shadows: coordShadow,
                    ),
                //),
              ),
            ),
            SlideTransition(
              position: _slideAnimation,
              child: FractionalTranslation(
                translation: kNextCoordFractionalTranslation,
                //child: Transform.scale(
                //  scale: kNextCoordScale,
                child: Text(
                  trainingController.nextCoord?.name ?? '',
                  style: DefaultTextStyle.of(context).style.copyWith(
                        fontSize: 150,
                        shadows: coordShadow,
                      ),
                ),
                //),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
