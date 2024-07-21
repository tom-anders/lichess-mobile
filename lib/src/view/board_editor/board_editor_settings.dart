import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chessground/chessground.dart' as cg;
import 'package:lichess_mobile/src/model/board_editor/board_editor_controller.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';

class BoardEditorSettings extends ConsumerWidget {
  const BoardEditorSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardEditorController = ref.watch(boardEditorControllerProvider);
    final boardEditorNotifier =
        ref.read(boardEditorControllerProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: .7,
      expand: false,
      snap: true,
      snapSizes: const [.7],
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        children: [
          SwitchSettingTile(
            title: const Text('White to play'),
            value: boardEditorController.sideToPlay == cg.Side.white,
            onChanged: (white) => boardEditorNotifier.setSideToPlay(
              white ? cg.Side.white : cg.Side.black,
            ),
          ),
          PlatformListTile(
            title: Text(context.l10n.castling, style: Styles.sectionTitle),
            subtitle: const SizedBox.shrink(),
          ),
          SwitchSettingTile(
            title: const Text('White O-O'),
            value: boardEditorController.canWhiteCastleKingside,
            onChanged: boardEditorNotifier.setWhiteKingsideCastlingAllowed,
          ),
          SwitchSettingTile(
            title: const Text('White O-O-O'),
            value: boardEditorController.canWhiteCastleQueenside,
            onChanged: boardEditorNotifier.setWhiteQueensideCastlingAllowed,
          ),
          SwitchSettingTile(
            title: const Text('Black O-O'),
            value: boardEditorController.canBlackCastleKingside,
            onChanged: boardEditorNotifier.setBlackKingsideCastlingAllowed,
          ),
          SwitchSettingTile(
            title: const Text('Black O-O-O'),
            value: boardEditorController.canBlackCastleQueenside,
            onChanged: boardEditorNotifier.setBlackQueensideCastlingAllowed,
          ),
        ],
      ),
    );
  }
}
