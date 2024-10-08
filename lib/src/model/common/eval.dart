import 'dart:math' as math;

import 'package:chessground/chessground.dart';
import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';

part 'eval.freezed.dart';
part 'eval.g.dart';

sealed class Eval {
  String get evalString;
  double winningChances(Side side);
}

/// The eval from an external engine, typically lichess server side stockfish.
@Freezed(fromJson: true, toJson: true)
class ExternalEval with _$ExternalEval implements Eval {
  const ExternalEval._();

  const factory ExternalEval({
    required int? cp,
    required int? mate,
    int? depth,
    UCIMove? bestMove,
    String? variation,
    ({String name, String comment})? judgment,
  }) = _ExternalEval;

  factory ExternalEval.fromJson(Map<String, dynamic> json) =>
      _$ExternalEvalFromJson(json);

  @override
  String get evalString => _evalString(cp, mate);

  @override
  double winningChances(Side side) => _toPov(side, _whiteWinningChances);

  double get _whiteWinningChances {
    if (mate != null) {
      return mateWinningChances(mate!);
    } else if (cp != null) {
      return cpWinningChances(cp!);
    } else {
      return 0;
    }
  }
}

double _toWhiteWinningChances(int? cp, int? mate) {
  if (mate != null) {
    return mateWinningChances(mate);
  } else if (cp != null) {
    return cpWinningChances(cp);
  } else {
    return 0;
  }
}

/// The eval from the client's own engine, typically stockfish.
@freezed
class ClientEval with _$ClientEval implements Eval {
  const ClientEval._();

  const factory ClientEval({
    required Position position,
    required int depth,
    required int nodes,
    required IList<PvData> pvs,
    required int millis,
    required int maxDepth,
    int? cp,
    int? mate,
  }) = _ClientEval;

  double get knps => nodes / millis;

  Move? get bestMove {
    final uci = pvs.firstOrNull?.moves.firstOrNull;
    if (uci == null) return null;
    return Move.parse(uci);
  }

  IList<MoveWithWinningChances> get bestMoves {
    return pvs
        .where((e) => e.moves.isNotEmpty)
        .map((e) => e._firstMoveWithWinningChances(position.turn))
        .nonNulls
        .sorted((a, b) => b.winningChances.compareTo(a.winningChances))
        .toIList();
  }

  @override
  String get evalString => _evalString(cp, mate);

  /// The winning chances for the given [Side].
  ///
  /// 1  = infinitely winning
  /// -1 = infinitely losing
  @override
  double winningChances(Side side) => _toPov(side, _whiteWinningChances);

  double get _whiteWinningChances {
    return _toWhiteWinningChances(cp, mate);
  }
}

@freezed
class PvData with _$PvData {
  const PvData._();
  const factory PvData({
    required IList<UCIMove> moves,
    int? mate,
    int? cp,
  }) = _PvData;

  String get evalString => _evalString(cp, mate);

  Side? get winningSide {
    if (mate != null) {
      return mate! > 0 ? Side.white : Side.black;
    } else if (cp != null) {
      return cp! > 0 ? Side.white : Side.black;
    } else {
      return null;
    }
  }

  List<String> sanMoves(Position fromPosition) {
    Position pos = fromPosition;
    final List<String> res = [];
    for (final uciMove in moves.sublist(0, math.min(12, moves.length))) {
      // assume uciMove string is valid as it comes from stockfish
      final move = Move.parse(uciMove)!;
      if (pos.isLegal(move)) {
        final (newPos, san) = pos.makeSanUnchecked(move);
        res.add(san);
        pos = newPos;
      } else {
        break;
      }
    }
    return res;
  }

  MoveWithWinningChances? _firstMoveWithWinningChances(Side sideToMove) {
    final uciMove = (moves.isNotEmpty) ? Move.parse(moves.first) : null;
    return (uciMove != null)
        ? (
            move: uciMove,
            winningChances:
                _toPov(sideToMove, _toWhiteWinningChances(cp, mate)),
          )
        : null;
  }
}

typedef MoveWithWinningChances = ({Move move, double winningChances});

ISet<Shape> computeBestMoveShapes(
  IList<MoveWithWinningChances> moves,
  Side sideToMove,
  PieceAssets pieceAssets,
) {
  // Scale down all moves with index > 0 based on how much worse their winning chances are compared to the best move
  // (assume moves are ordered by their winning chances, so index==0 is the best move)
  double scaleArrowAgainstBestMove(int index) {
    const minScale = 0.15;
    const maxScale = 1.0;
    const winningDiffScaleFactor = 2.5;

    final bestMove = moves[0];
    final winningDiffComparedToBestMove =
        bestMove.winningChances - moves[index].winningChances;
    // Force minimum scale if the best move is significantly better than this move
    if (winningDiffComparedToBestMove > 0.3) {
      return minScale;
    }
    return clampDouble(
      math.max(
        minScale,
        maxScale - winningDiffScaleFactor * winningDiffComparedToBestMove,
      ),
      0,
      1,
    );
  }

  return ISet(
    moves.mapIndexed(
      (i, m) {
        final move = m.move;
        // Same colors as in the Web UI with a slightly different opacity
        // The best move has a different color than the other moves
        final color = Color((i == 0) ? 0x66003088 : 0x664A4A4A);
        switch (move) {
          case NormalMove(from: _, to: _, promotion: final promRole):
            return [
              Arrow(
                color: color,
                orig: move.from,
                dest: move.to,
                scale: scaleArrowAgainstBestMove(i),
              ),
              if (promRole != null)
                PieceShape(
                  color: color,
                  orig: move.to,
                  pieceAssets: pieceAssets,
                  piece: Piece(color: sideToMove, role: promRole),
                ),
            ];
          case DropMove(role: final role, to: _):
            return [
              PieceShape(
                color: color,
                orig: move.to,
                pieceAssets: pieceAssets,
                opacity: 0.5,
                piece: Piece(color: sideToMove, role: role),
              ),
            ];
        }
      },
    ).expand((e) => e),
  );
}

double cpToPawns(int cp) => cp / 100;

int cpFromPawns(double pawns) => (pawns * 100).round();

double cpWinningChances(int cp) =>
    _rawWinningChances(math.min(math.max(-1000, cp), 1000));

double mateWinningChances(int mate) {
  final cp = (21 - math.min(10, mate.abs())) * 100;
  final signed = cp * (mate > 0 ? 1 : -1);
  return _rawWinningChances(signed);
}

double _toPov(Side side, double diff) => side == Side.white ? diff : -diff;

// https://github.com/lichess-org/lila/pull/11148
double _rawWinningChances(num cp) {
  // https://github.com/lichess-org/lila/pull/11148
  const multiplier = -0.00368208;
  return 2 / (1 + math.exp(multiplier * cp)) - 1;
}

String _evalString(int? cp, int? mate) {
  if (cp != null) {
    final e = cpToPawns(cp);
    return e > 0 ? '+${e.toStringAsFixed(1)}' : e.toStringAsFixed(1);
  } else if (mate != null) {
    return '#$mate';
  } else {
    return '-';
  }
}
