import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nrs_app/common.dart';
import 'package:nrs_app/sync.dart';
import 'package:nrs_app/utils.dart';

class AniListAuthData {
  String username;
  String accessToken;

  AniListAuthData(this.username, this.accessToken);
}

class AniList extends Service<AniListAuthData> {
  static final Uri baseUri = Uri.https("graphql.anilist.co", "");
  static final Map<Status, String> statusToAL = {
    Status.ptw: "PLANNING",
    Status.dropped: "DROPPED",
    Status.onHold: "PAUSED",
    Status.watching: "CURRENT",
    Status.completed: "COMPLETED",
  };

  static final Map<String, Status> alToStatus =
      statusToAL.map((key, value) => MapEntry(value, key));
  @override
  String? getIdFromAOD(List<String> sources) {
    return getIdFromAODByURLPrefix(sources, "anilist.co/anime/");
  }

  @override
  String? getIdFromEntry(nrsEntry) {
    return getIdFromEntryByDAHAdditionalSources(nrsEntry, "id_AniList");
  }

  @override
  Future<Map<String, AnimeListEntry>> loadUserAnimeList(
      http.Client client, AniListAuthData auth) async {
    var result = <String, AnimeListEntry>{};
    var hasNextPage = true;
    var pageIndex = 1;

    const graphql = r"""
      query($page: Int, $username: String) {
        Page(page: $page) {
          pageInfo {
            hasNextPage
          }
          
          mediaList(userName: $username, type:ANIME) {
            mediaId
            status
            score
            progress
          }
        }
      }
    """;
    while (hasNextPage) {
      final response = await client.post(baseUri, body: {
        'query': graphql,
        'variables': jsonEncode({
          'page': pageIndex,
          'username': auth.username,
        }),
      }, headers: {
        "Authorization": "Bearer ${auth.accessToken}"
      });

      final json = await response.jsonOrThrow;

      hasNextPage = json["data"]["Page"]["pageInfo"]["hasNextPage"];
      pageIndex++;

      for (final entry in json["data"]["Page"]["mediaList"]) {
        final id = entry["mediaId"].toString();
        final status = alToStatus[entry["status"]]!;
        final score = getRawScore(entry["score"].toDouble());
        final episode = entry["progress"];
        result[id] = AnimeListEntry(id, score, status, episode);
      }
    }

    return result;
  }

  @override
  int getRawScore(double score) {
    return (score * 10).round();
  }

  @override
  Future<void> updateAnimeEntry(
      http.Client client, AniListAuthData auth, AnimeListEntry entry) async {
    const graphql = r"""
      mutation($id: Int, $scoreRaw: Int, $status: MediaListStatus, $progress: Int) {
        SaveMediaListEntry(mediaId: $id, scoreRaw: $scoreRaw, status: $status, progress: $progress) {
          id
        }
      }
    """;

    final response = await client.post(baseUri, body: {
      'query': graphql,
      'variables': jsonEncode({
        'id': int.parse(entry.id),
        'scoreRaw': entry.rawScore,
        'status': statusToAL[entry.status]!,
        'progress': entry.episode,
      }),
    }, headers: {
      "Authorization": "Bearer ${auth.accessToken}"
    });

    response.bodyOrThrow;
  }
}
