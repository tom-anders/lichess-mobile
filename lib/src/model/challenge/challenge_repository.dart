import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:deep_pick/deep_pick.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lichess_mobile/src/model/challenge/challenge.dart';
import 'package:lichess_mobile/src/model/common/game.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/network/aggregator.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'challenge_repository.g.dart';

@Riverpod(keepAlive: true)
ChallengeRepository challengeRepository(Ref ref) {
  return ChallengeRepository(ref.read(lichessClientProvider), ref.read(aggregatorProvider));
}

typedef ChallengesList = ({IList<Challenge> inward, IList<Challenge> outward});

class ChallengeRepository {
  const ChallengeRepository(this.client, this.aggregator);

  final LichessClient client;
  final Aggregator aggregator;

  Future<ChallengesList> list() {
    final uri = Uri(path: '/api/challenge');
    return aggregator.readJson(
      uri,
      atomicMapper: (json) {
        final listPick = pick(json).required();
        final inward = listPick('in').asListOrEmpty(Challenge.fromPick);
        final outward = listPick('out').asListOrEmpty(Challenge.fromPick);

        return (inward: inward.lock, outward: outward.lock);
      },
    );
  }

  Future<Challenge> show(ChallengeId id) {
    final uri = Uri(path: '/api/challenge/$id/show');
    return client.readJson(uri, mapper: Challenge.fromServerJson);
  }

  Future<Challenge> create(ChallengeRequest challengeReq) async {
    final uri = Uri(path: '/api/challenge/${challengeReq.destUser?.id ?? 'open'}');
    final challenge = await client.postReadJson(
      uri,
      body: challengeReq.toRequestBody,
      mapper: Challenge.fromServerJson,
    );

    // The API doesn't directly allow us to create an open challenge and also join it in one step,
    // so after having created the challenge, we immediately accept it if it's an open challenge.
    if (challengeReq.destUser == null) {
      final side = switch (challengeReq.sideChoice) {
        SideChoice.white => Side.white,
        SideChoice.black => Side.black,
        SideChoice.random => Side.values[Random().nextInt(Side.values.length)],
      };
      await accept(challenge.id, side: side);
    }

    return challenge;
  }

  Future<void> accept(ChallengeId id, {Side? side}) async {
    final uri = Uri(
      path: '/api/challenge/$id/accept',
      queryParameters: {if (side != null) 'color': side.name},
    );
    final response = await client.post(uri);

    if (response.statusCode >= 400) {
      throw http.ClientException('Failed to accept challenge: ${response.statusCode}', uri);
    }
  }

  Future<void> decline(ChallengeId id, {ChallengeDeclineReason? reason}) async {
    final uri = Uri(path: '/api/challenge/$id/decline');
    final response = await client.post(uri, body: reason != null ? {'reason': reason.name} : null);

    if (response.statusCode >= 400) {
      throw http.ClientException('Failed to decline challenge: ${response.statusCode}', uri);
    }
  }

  Future<void> cancel(ChallengeId id) async {
    final uri = Uri(path: '/api/challenge/$id/cancel');
    final response = await client.post(uri);

    if (response.statusCode >= 400) {
      throw http.ClientException('Failed to cancel challenge: ${response.statusCode}', uri);
    }
  }
}
