import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' as dc;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'board_editor_controller.freezed.dart';
part 'board_editor_controller.g.dart';

@riverpod
class BoardEditorController extends _$BoardEditorController {
  @override
  BoardEditorState build() {
    return BoardEditorState(
      orientation: Side.white,
      sideToPlay: Side.white,
      pieces: readFen(dc.kInitialFEN).lock,
      unmovedRooks: dc.SquareSet.corners,
    );
  }

  void discardPiece(SquareId square) {
    _updatePosition(state.pieces.remove(square));
  }

  void movePiece(SquareId? origin, SquareId destination, Piece piece) {
    _updatePosition(
      state.pieces.remove(origin ?? destination).add(destination, piece),
    );
  }

  void flipBoard() {
    state = state.copyWith(
      orientation: state.orientation.opposite,
    );
  }

  void setSideToPlay(Side side) {
    state = state.copyWith(
      sideToPlay: side,
    );
  }

  void loadFen(String fen) {
    _updatePosition(readFen(fen).lock);
  }

  void _updatePosition(IMap<SquareId, Piece> pieces) {
    state = state.copyWith(pieces: pieces);
  }

  void setWhiteKingsideCastlingAllowed(bool allowed) {
    _setRookUnmoved(dc.Squares.h1, allowed);
  }

  void setWhiteQueensideCastlingAllowed(bool allowed) {
    _setRookUnmoved(dc.Squares.a1, allowed);
  }

  void setBlackKingsideCastlingAllowed(bool allowed) {
    _setRookUnmoved(dc.Squares.h8, allowed);
  }

  void setBlackQueensideCastlingAllowed(bool allowed) {
    _setRookUnmoved(dc.Squares.a8, allowed);
  }

  void _setRookUnmoved(dc.Square square, bool unmoved) {
    state = state.copyWith(
      unmovedRooks: unmoved
          ? state.unmovedRooks.withSquare(square)
          : state.unmovedRooks.withoutSquare(square),
    );
  }
}

@freezed
class BoardEditorState with _$BoardEditorState {
  const BoardEditorState._();

  const factory BoardEditorState({
    required Side orientation,
    required Side sideToPlay,
    required IMap<SquareId, Piece> pieces,
    required dc.SquareSet unmovedRooks,
  }) = _BoardEditorState;

  bool get canWhiteCastleKingside => unmovedRooks.has(dc.Squares.h1);
  bool get canWhiteCastleQueenside => unmovedRooks.has(dc.Squares.a1);
  bool get canBlackCastleKingside => unmovedRooks.has(dc.Squares.h8);
  bool get canBlackCastleQueenside => unmovedRooks.has(dc.Squares.a8);

  dc.Setup get _setup {
    final boardFen = writeFen(pieces.unlock);
    final board = dc.Board.parseFen(boardFen);
    return dc.Setup(
      board: board,
      // The user can toggle castling rights (i.e. unmovedRooks) regardless of the current position.
      // So keep only the rook starting squares where there's actually still a rook here.
      unmovedRooks: board.rooks.intersect(unmovedRooks),
      turn: sideToPlay == Side.white ? dc.Side.white : dc.Side.black,
      halfmoves: 0,
      fullmoves: 1,
    );
  }

  String get fen => _setup.fen;

  String? get pgn {
    try {
      final position = dc.Chess.fromSetup(_setup);
      return dc.PgnGame(
        headers: {'FEN': position.fen},
        moves: dc.PgnNode<dc.PgnNodeData>(),
        comments: [],
      ).makePgn();
    } catch (_) {
      return null;
    }
  }
}
