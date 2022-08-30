import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

enum Status {
  completed,
  watching,
  dropped,
  onHold,
  ptw,
}

Status statusFromNRSString(String str) {
  final lower = str.toLowerCase();
  if (lower.contains("completed") || lower == "partially dropped") {
    return Status.completed;
  } else if (lower.contains("watching")) {
    return Status.watching;
  } else if (lower.contains("dropped")) {
    return Status.dropped;
  } else if (lower.contains("on-hold")) {
    return Status.onHold;
  } else {
    return Status.ptw;
  }
}

int getDefaultStatusEpisodes(Status status, int totalEpisodes) {
  return status == Status.completed ? totalEpisodes : 0;
}

class AnimeListEntry {
  String id;
  int rawScore;
  Status status;
  int? episode;

  AnimeListEntry(this.id, this.rawScore, this.status, this.episode);

  bool needsUpdate(AnimeListEntry? other) {
    return other != null &&
        id == other.id &&
        rawScore == other.rawScore &&
        status == other.status &&
        episode == other.episode;
  }
}

bool needsUpdate(AnimeListEntry nrsEntry, AnimeListEntry? serviceEntry) {
  if (serviceEntry == null ||
      nrsEntry.rawScore != serviceEntry.rawScore ||
      nrsEntry.status != serviceEntry.status) {
    return true;
  }

  return nrsEntry.episode != null && nrsEntry.episode != serviceEntry.episode;
}

abstract class Service<AuthData> {
  String? getIdFromEntry(dynamic nrsEntry);
  String? getIdFromAOD(List<String> sources);
  int getRawScore(double score);

  Future<Map<String, AnimeListEntry>> loadUserAnimeList(
      http.Client client, AuthData auth);
  Future<void> updateAnimeEntry(
      http.Client client, AuthData auth, AnimeListEntry entry);

  Map<String, AnimeListEntry> createAnimeMapFromNRSEntries(
      Map<String, dynamic> entries, Map<String, dynamic> scores) {
    var result = <String, AnimeListEntry>{};
    entries.forEach((key, value) {
      final id = getIdFromEntry(value);
      if (id == null) {
        return;
      }
      final score =
          getRawScore(scores[key]["DAH_meta"]["DAH_anime_normalize"]["score"]);
      final status = statusFromNRSString(
          value["DAH_meta"]["DAH_entry_progress"]["status"]);
      var episode = value["DAH_meta"]["DAH_entry_progress"]["episode"];
      result[id] = AnimeListEntry(id, score, status, episode);
    });
    return result;
  }
}

Future<List<dynamic>> loadAnimeOfflineDatabase(
    CacheManager cache, Uri uri) async {
  final file = await cache.downloadFile(uri.toString());
  final content = await file.file.readAsString();
  final json = await compute(jsonDecode, content);
  return json["data"];
}

Future<Map<String, dynamic>> loadNRSFilteredEntryList(
    CacheManager cache, Uri uri) async {
  final file = await cache.downloadFile(uri.toString());
  final content = await file.file.readAsString();
  final json = await compute(jsonDecode, content);
  var result = <String, dynamic>{};
  json.forEach((key, value) {
    if (key.startsWith("A-")) {
      result[key] = value;
    }
  });

  return result;
}

Future<void> sync<AuthData>(
    List<dynamic> animeOfflineDatabase,
    Service<AuthData> service,
    http.Client client,
    Map<String, dynamic> nrsEntries,
    Map<String, dynamic> nrsScores,
    AuthData authData,
    void Function(String) log) async {
  final nrsList = service.createAnimeMapFromNRSEntries(nrsEntries, nrsScores);
  log("Loading user anime list");
  final serviceList = await service.loadUserAnimeList(client, authData);
  nrsList.removeWhere((id, entry) => !needsUpdate(entry, serviceList[id]));
  for (final entry in nrsList.values) {
    log("Updating entry: ${entry.id}");
    await service.updateAnimeEntry(client, authData, entry);
  }
}
