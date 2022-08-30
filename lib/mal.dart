import 'package:http/http.dart' as http;
import 'package:nrs_app/sync.dart';
import 'package:nrs_app/utils.dart';

import 'common.dart';

class MAL extends Service<String> {
  static final Map<Status, String> statusToMAL = {
    Status.ptw: "plan_to_watch",
    Status.dropped: "dropped",
    Status.onHold: "on_hold",
    Status.watching: "watching",
    Status.completed: "completed",
  };

  static final Map<String, Status> malToStatus =
      statusToMAL.map((key, value) => MapEntry(value, key));

  @override
  String? getIdFromAOD(List<String> sources) {
    return getIdFromAODByURLPrefix(sources, "myanimelist.net/anime/");
  }

  @override
  String? getIdFromEntry(nrsEntry) {
    return getIdFromEntryByDAHAdditionalSources(nrsEntry, "id_MyAnimeList");
  }

  @override
  Future<Map<String, AnimeListEntry>> loadUserAnimeList(
      http.Client client, String authData) async {
    var result = <String, AnimeListEntry>{};
    Uri? nextPageUri = Uri.https(
      "api.myanimelist.net",
      "/v2/users/@me/animelist",
      {"fields": "list_status", "limit": "1000", "nsfw": "true"},
    );

    while (nextPageUri != null) {
      final response = await client.get(nextPageUri, headers: {
        "Authorization": "Bearer $authData",
      });
      final json = await response.jsonOrThrow;
      if (json["paging"].containsKey("next")) {
        nextPageUri = Uri.parse(json["paging"]["next"]);
      } else {
        nextPageUri = null;
      }
      for (final entry in json["data"]) {
        final id = entry["node"]["id"].toString();
        final score = getRawScore(entry["list_status"]["score"].toDouble());
        final status = malToStatus[entry["list_status"]["status"]]!;
        final episode = entry["list_status"]["num_episodes_watched"];
        result[id] = AnimeListEntry(id, score, status, episode);
      }
    }

    return result;
  }

  @override
  int getRawScore(double score) {
    return score.round();
  }

  @override
  Future<void> updateAnimeEntry(
      http.Client client, String authData, AnimeListEntry entry) async {
    final response = await client.put(
      Uri.https("api.myanimelist.net", "/v2/anime/${entry.id}/my_list_status"),
      headers: {
        "Authorization": "Bearer $authData",
      },
      body: {
        "status": statusToMAL[entry.status],
        "num_watched_episodes": entry.episode.toString(),
        "score": entry.rawScore.toString(),
      },
    );

    response.bodyOrThrow;
  }
}
