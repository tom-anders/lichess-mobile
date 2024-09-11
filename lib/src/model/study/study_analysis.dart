import 'package:chessground/chessground.dart';
import 'package:collection/collection.dart';
import 'package:dartchess/dartchess.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/user/user.dart';

part 'study_analysis.freezed.dart';
part 'study_analysis.g.dart';

@Freezed()
class StudyAnalysis with _$StudyAnalysis {
  const StudyAnalysis._();

  const factory StudyAnalysis({
    required Side orientation,
    required String initialFen,
    required Variant variant,
    required IList<StudyTreePart> treeParts,
  }) = _StudyAnalysis;

  factory StudyAnalysis.fromJson(Map<String, dynamic> json) {
    return _studyAnalyseDataFromPick(pick(json).required());
  }
}

StudyAnalysis _studyAnalyseDataFromPick(RequiredPick pick) {
  return StudyAnalysis(
    orientation: pick('orientation').asSideOrThrow(),
    initialFen: pick('game', 'initialFen').asStringOrThrow(),
    variant: pick('game', 'variant').asVariantOrThrow(),
    treeParts: pick('treeParts')
        .asListOrThrow(
          (pick) => StudyTreePart.fromJson(pick.asMapOrThrow()),
        )
        .toIList(),
  );
}

@Freezed(fromJson: true)
class StudyTreePart with _$StudyTreePart {
  const StudyTreePart._();

  const factory StudyTreePart({
    required int ply,
    required String fen,
    required StudyTreePartId? id,
    required String? san,
    required UCIMove? uci,
    required IList<StudyNodeComment>? comments,
    required IList<StudyNodeGlyph>? glyphs,
    @ShapeConverter() required IList<Shape>? shapes,
    required IList<StudyTreePart>? children,
  }) = _StudyTreePart;

  factory StudyTreePart.fromJson(Map<String, Object?> json) =>
      _$StudyTreePartFromJson(json);
}

class ShapeConverter implements JsonConverter<Shape, Map<String, Object?>> {
  const ShapeConverter();

  // assume we are serializing only valid uci strings
  @override
  Shape fromJson(Map<String, Object?> json) {
    final pick = RequiredPick(json);
    final brush = pick('brush').asStringOrThrow();
    final color = (ShapeColor.values.firstWhereOrNull(
              (color) => color.name == brush,
            ) ??
            ShapeColor.green)
        .color;
    final orig = pick('orig').asSquareOrThrow();
    final dest = pick('dest').asSquareOrNull();
    return dest != null
        ? Arrow(color: color, orig: orig, dest: dest)
        : Circle(color: color, orig: orig);
  }

  @override
  Map<String, Object?> toJson(Shape shape) {
    throw UnimplementedError();
  }
}

@Freezed(fromJson: true)
class StudyNodeComment with _$StudyNodeComment {
  const StudyNodeComment._();

  const factory StudyNodeComment({
    required StudyNodeCommentId id,
    required String text,
    required LightUser by,
  }) = _StudyNodeComment;

  factory StudyNodeComment.fromJson(Map<String, Object?> json) =>
      _$StudyNodeCommentFromJson(json);
}

@Freezed(fromJson: true)
class StudyNodeGlyph with _$StudyNodeGlyph {
  const StudyNodeGlyph._();

  const factory StudyNodeGlyph({
    @JsonKey(name: 'id') required int nag,
    required String symbol,
  }) = _StudyNodeGlyph;

  factory StudyNodeGlyph.fromJson(Map<String, Object?> json) =>
      _$StudyNodeGlyphFromJson(json);
}
