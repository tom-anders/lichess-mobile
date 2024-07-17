import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart' as cg;
import 'package:dartchess/dartchess.dart' as dc;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_text_field.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar_button.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';

class BoardEditorScreen extends StatelessWidget {
  const BoardEditorScreen({super.key});

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
        title: Text(context.l10n.boardEditor),
      ),
      body: const _Body(),
    );
  }

  Widget _iosBuilder(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Styles.cupertinoScaffoldColor.resolveFrom(context),
        border: null,
        middle: Text(context.l10n.boardEditor),
      ),
      child: const _Body(),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Board(boardSize, isTablet: isTablet),
                    ColoredBox(
                      color: Colors.grey,
                      child: Flex(
                        direction: direction,
                        children: [
                          _PieceMenu(
                            boardSize,
                            direction: flipAxis(direction),
                            side: cg.Side.white,
                          ),
                          _PieceMenu(
                            boardSize,
                            direction: flipAxis(direction),
                            side: cg.Side.black,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        _BottomBar(),
      ],
    );
  }
}

class _Board extends ConsumerStatefulWidget {
  const _Board(
    this.boardSize, {
    required this.isTablet,
  });

  final double boardSize;
  final bool isTablet;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  @override
  Widget build(BuildContext context) {
    final boardPrefs = ref.watch(boardPreferencesProvider);

    return cg.BoardEditor(
      size: widget.boardSize,
      initialFen: dc.kInitialBoardFEN,
      orientation: cg.Side.white, // TODO allow to flip
      settings: cg.BoardEditorSettings(
        pieceAssets: boardPrefs.pieceSet.assets,
        colorScheme: boardPrefs.boardTheme.colors,
        enableCoordinates: boardPrefs.coordinates,
        borderRadius: widget.isTablet
            ? const BorderRadius.all(Radius.circular(4.0))
            : BorderRadius.zero,
        boxShadow: widget.isTablet ? boardShadows : const <BoxShadow>[],
      ),
    );
  }
}

class _PieceMenu extends ConsumerStatefulWidget {
  const _PieceMenu(
    this.boardSize, {
    required this.direction,
    required this.side,
  });

  final double boardSize;

  final Axis direction;

  final cg.Side side;

  @override
  ConsumerState<_PieceMenu> createState() => _PieceMenuState();
}

class _PieceMenuState extends ConsumerState<_PieceMenu> {
  @override
  Widget build(BuildContext context) {
    final boardPrefs = ref.watch(boardPreferencesProvider);

    return Flex(
      direction: widget.direction,
      mainAxisAlignment: MainAxisAlignment.center,
      children: cg.Role.values.map(
        (role) {
          final pieceWidget = cg.PieceWidget(
            piece: cg.Piece(role: role, color: widget.side),
            size: widget.boardSize / 8,
            pieceAssets: boardPrefs.pieceSet.assets,
          );

          // TODO double size+offset like in the normal board
          return Draggable(
            data: cg.Piece(role: role, color: widget.side),
            feedback: pieceWidget,
            child: pieceWidget,
          );
        },
      ).toList(),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Theme.of(context).platform == TargetPlatform.iOS
          ? CupertinoTheme.of(context).barBackgroundColor
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
                  label: context.l10n.settingsSettings,
                  onTap: () {},
                  icon: Icons.settings,
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  label: context.l10n.flipBoard,
                  onTap: () {},
                  icon: Icons.flip,
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  label: context.l10n.continueFromHere,
                  onTap: () {},
                  icon: LichessIcons.crossed_swords,
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  label: context.l10n.analysis,
                  onTap: () {},
                  icon: LichessIcons.microscope,
                ),
              ),
              Expanded(
                child: BottomBarButton(
                  label: context.l10n.mobileSharePositionAsFEN,
                  onTap: () {},
                  icon: Icons.share,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
