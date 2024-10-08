import 'dart:convert';

import 'package:deep_pick/deep_pick.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:http/http.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/study/study.dart';
import 'package:lichess_mobile/src/model/study/study_filter.dart';
import 'package:lichess_mobile/src/network/http.dart';

class StudyRepository {
  StudyRepository(this.client);

  final Client client;

  Future<IList<StudyPageData>> getStudies({
    required StudyCategory category,
    required StudyListOrder order,
    int page = 1,
  }) {
    return _requestStudies(
      path: '${category.name}/${order.name}',
      queryParameters: {'page': page.toString()},
    );
  }

  Future<IList<StudyPageData>> searchStudies({
    required String query,
    int page = 1,
  }) {
    return _requestStudies(
      path: 'search',
      queryParameters: {'page': page.toString(), 'q': query},
    );
  }

  Future<IList<StudyPageData>> _requestStudies({
    required String path,
    required Map<String, String> queryParameters,
  }) {
    return client.readJson(
      Uri(
        path: '/study/$path',
        queryParameters: queryParameters,
      ),
      headers: {'Accept': 'application/json'},
      mapper: (Map<String, dynamic> json) {
        final paginator =
            pick(json, 'paginator').asMapOrThrow<String, dynamic>();

        return pick(paginator, 'currentPageResults')
            .asListOrThrow(
              (pick) => StudyPageData.fromJson(pick.asMapOrThrow()),
            )
            .toIList();
      },
    );
  }

  Future<(Study study, String pgn)> getStudy({
    required StudyId id,
    StudyChapterId? chapterId,
  }) async {
    final study = await client.readJson(
      Uri(
        path: (chapterId != null) ? '/study/$id/$chapterId' : '/study/$id',
        queryParameters: {
          'chapters': '1',
        },
      ),
      headers: {'Accept': 'application/json'},
      mapper: (Map<String, dynamic> json) {
        return Study.fromJson(
          pick(json, 'study').asMapOrThrow(),
        );
      },
    );

    final bytes = await client.readBytes(
      Uri(path: '/api/study/$id/${chapterId ?? study.chapter.id}.pgn'),
      headers: {'Accept': 'application/x-chess-pgn'},
    );

    return (study, utf8.decode(bytes));
  }
}
