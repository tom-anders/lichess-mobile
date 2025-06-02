import 'package:dartchess/dartchess.dart';
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

  const factory Forecast(bool myTurn, IList<UciPath> lines) = _Forecast;

  factory Forecast.fromJson(Map<String, dynamic> json) => _$ForecastFromJson(json);
}
