import 'package:dartchess/dartchess.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
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
    required IList<StudyAnalyseNode> treeParts,
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
        .asListOrThrow((pick) => StudyAnalyseNode.fromJson(pick.asMapOrThrow()))
        .toIList(),
  );
}

@Freezed(fromJson: true)
class StudyAnalyseNode with _$StudyAnalyseNode {
  const StudyAnalyseNode._();

  const factory StudyAnalyseNode({
    required int ply,
    required String fen,
    required StudyAnalyseNodeId id,
    required SanMove san,
    required UCIMove uci,
    required IList<StudyNodeComment> comments,
    required IList<StudyNodeGlyph> glyphs,
    required IList<StudyNodeShapes> shapes,
    required IList<StudyAnalyseNode>? children,
  }) = _StudyAnalyseNode;

  factory StudyAnalyseNode.fromJson(Map<String, Object?> json) =>
      _$StudyAnalyseNodeFromJson(json);
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
    required int id,
    required String symbol,
    required String name,
  }) = _StudyNodeGlyph;

  factory StudyNodeGlyph.fromJson(Map<String, Object?> json) =>
      _$StudyNodeGlyphFromJson(json);
}

@Freezed(fromJson: true)
class StudyNodeShapes with _$StudyNodeShapes {
  const StudyNodeShapes._();

  const factory StudyNodeShapes({
    required String brush,
    required Square orig,
    required Square? dest,
  }) = _StudyNodeShapes;

  factory StudyNodeShapes.fromJson(Map<String, Object?> json) =>
      _$StudyNodeShapesFromJson(json);
}
