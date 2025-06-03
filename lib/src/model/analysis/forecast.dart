import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/node.dart';
import 'package:lichess_mobile/src/model/common/uci.dart';

part 'forecast.freezed.dart';
part 'forecast.g.dart';

/// Logic based on ForecastCtrl from lichobile
@Freezed(fromJson: true, toJson: true)
sealed class Forecast with _$Forecast {
  const Forecast._();

  const factory Forecast(
    bool onMyTurn,
    @JsonKey(fromJson: _linesFromJson, toJson: _linesToJson) IList<UciPath> lines,
  ) = _Forecast;

  factory Forecast.fromJson(Map<String, dynamic> json) => _$ForecastFromJson(json);

  factory Forecast.fromServerJson(Map<String, dynamic> json) =>
      forecastFromPick(pick(json).required());

  // TODO we currently have no mapping from UciCharPair back to an UCI string.
  // But we can use the Node API to get the nodes on a path and get the UCI from that.
  // For that, the parameter needs to be the node corresponding to the current live move
  // TODO toServerJson(Branch currentMove);
  // old implementation from CorrespondenceForcast:
  //String toJson() => jsonEncode({
  //  'onMyTurn': onMyTurn,
  //  'steps': steps
  //      .map(
  //        (forecast) => forecast
  //            .mapIndexed(
  //              (i, step) => {
  //                'ply': step.ply,
  //                'uci': step.sanMove.move.uci,
  //                'san': step.sanMove.san,
  //                'fen': step.fen,
  //              },
  //            )
  //            .toList(growable: false),
  //      )
  //      .toList(growable: false),
  //});
}

Forecast forecastFromPick(RequiredPick pick) => Forecast(
  pick('onMyTurn').asBoolOrFalse(),
  IList(
    pick('steps').asListOrThrow(
      (pick) => UciPath.fromUciMoves(pick.asListOrThrow((pick) => pick('uci').asStringOrThrow())),
    ),
  ),
);

IList<UciPath> _linesFromJson(String json) =>
    (jsonDecode(json) as List<dynamic>).map((line) => UciPath(line as String)).toIList();

String _linesToJson(IList<UciPath> lines) {
  final objs = lines.map((line) => line.value).toList(growable: false);
  return jsonEncode(objs);
}
