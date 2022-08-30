import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:localstorage/localstorage.dart';
import 'package:nrs_app/anilist.dart';
import 'package:nrs_app/auth.dart';
import 'package:http/http.dart' as http;
import 'package:nrs_app/mal.dart';
import 'package:nrs_app/sync.dart';
import 'package:nrs_app/utils.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

typedef LogCallback = void Function(String);

enum TextFieldLabel {
  nrsImplGitRepoUri,
  entriesJsonUri,
  scoresJsonUri,
  aodJsonUri,
  malAccessToken,
  malRefreshToken,
  anilistUsername,
  anilistAccessToken,
  malClientId,
  anilistClientId,
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late http.Client client;
  late List<TextEditingController> controllers;
  late TextEditingController dialogController, logController;
  bool init = false;
  final LocalStorage ls = LocalStorage('nrs-sync');
  late DefaultCacheManager cache;
  static final Map<String, String> defaultData = {
    'nrsImplGitRepoUri': 'https://github.com/ngoduyanh/nrs-impl-kt',
    'entriesJsonUri':
        'https://github.com/ngoduyanh/nrs-impl-kt/raw/master/output/entries.json',
    'scoresJsonUri':
        'https://github.com/ngoduyanh/nrs-impl-kt/raw/master/output/scores.json',
    'aodJsonUri':
        'https://github.com/manami-project/anime-offline-database/raw/master/anime-offline-database-minified.json',
    'malAccessToken': '',
    'malRefreshToken': '',
    'anilistAccessToken': '',
    'anilistUsername': '',
    'malClientId': '',
    'anilistClientId': '',
  };
  Map<String, String> data = {...defaultData};

  _MainPageState() {
    final lsData = ls.getItem("data");
    if (lsData == null) {
      return;
    }
    for (var label in TextFieldLabel.values) {
      var lsValue = lsData[label.name];
      if (lsValue != null) {
        data[label.name] = lsValue;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    cache = DefaultCacheManager();
    client = http.Client();
    controllers = TextFieldLabel.values
        .map((label) => TextEditingController())
        .toList(growable: false);
    dialogController = TextEditingController();
    logController = TextEditingController(text: "Log:\n");
  }

  @override
  void dispose() {
    logController.dispose();
    dialogController.dispose();
    for (var c in controllers) {
      c.dispose();
    }
    client.close();
    ls.dispose();
    cache.dispose();
    super.dispose();
  }

  void _saveToStorage() {
    ls.setItem('data', data);
  }

  void _clearStorage() async {
    await ls.clear();
    setState(() {
      data = {...defaultData};
    });
  }

  Future<void> errorDialog(BuildContext context, HttpException error) async {
    await showDialog(
        context: context,
        builder: (context) => AlertDialog(title: Text(error.toString())));
  }

  Future<Map<String, String>> getData() async {
    await ls.ready;
    final lsData = ls.getItem("data");
    final data = {...defaultData};
    if (lsData != null) {
      for (final label in TextFieldLabel.values) {
        final lsValue = lsData[label.name];
        if (lsValue != null) {
          data[label.name] = lsValue;
        }
      }
    }
    return data;
  }

  void log(String msg) {
    setState(() {
      final now = DateFormat('HH:mm:ss').format(DateTime.now());
      logController.text += "[$now] $msg\n";
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: getData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text("Loading...")),
          );
        }

        data = snapshot.data!;
        for (var label in TextFieldLabel.values) {
          controllers[label.index].text = data[label.name]!;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('NRS Sync Application'),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(8.0),
            itemCount: TextFieldLabel.values.length + 1,
            itemBuilder: (context, index) {
              if (index == TextFieldLabel.values.length) {
                return Container(
                  color: Colors.white30,
                  padding: const EdgeInsets.all(7.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: TextField(
                      maxLines: null,
                      readOnly: true,
                      textAlignVertical: TextAlignVertical.center,
                      controller: logController,
                    ),
                    // ends the actual text box
                  ),
                );
              }
              return TextField(
                controller: controllers[index],
                onSubmitted: (value) async {
                  setState(() {
                    data[TextFieldLabel.values[index].name] = value;
                    _saveToStorage();
                  });
                },
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: {
                      TextFieldLabel.entriesJsonUri: "URI to entries.json",
                      TextFieldLabel.scoresJsonUri: "URI to scores.json",
                      TextFieldLabel.aodJsonUri:
                          "URI to anime-offline-database(-minified).json",
                      TextFieldLabel.malAccessToken: "MyAnimeList access token",
                      TextFieldLabel.malRefreshToken:
                          "MyAnimeList refresh token",
                      TextFieldLabel.malClientId: "MyAnimeList client ID",
                      TextFieldLabel.anilistUsername: "AniList username",
                      TextFieldLabel.anilistAccessToken: "AniList access token",
                      TextFieldLabel.anilistClientId: "AniList client ID",
                      TextFieldLabel.nrsImplGitRepoUri:
                          "NRS (implementation) Git repo URI",
                    }[TextFieldLabel.values[index]]!),
              );
            },
            separatorBuilder: (context, index) => const Divider(),
          ),
          floatingActionButton: PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text("Refresh MAL tokens"),
                onTap: () async {
                  try {
                    final tokens = await refreshMALToken(
                        client,
                        data[TextFieldLabel.malRefreshToken.name]!,
                        data[TextFieldLabel.malClientId.name]!);
                    setState(() {
                      data[TextFieldLabel.malRefreshToken.name] =
                          tokens.refreshToken;
                      data[TextFieldLabel.malAccessToken.name] =
                          tokens.accessToken;
                      _saveToStorage();
                    });
                  } on HttpException catch (e) {
                    await errorDialog(context, e);
                  }
                },
              ),
              PopupMenuItem(
                onTap: () async {
                  final codeChallenge = malRandomCodeChallenge();
                  final codeVerifier = codeChallenge;
                  malAuthorize(
                      codeChallenge, data[TextFieldLabel.malClientId.name]!);
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    dialogController.text = "";
                    final code = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        contentPadding: const EdgeInsets.all(8.0),
                        content: TextField(
                          controller: dialogController,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText:
                                  "Copy-paste the token/redirect URL here"),
                        ),
                        actions: [
                          TextButton(
                            child: const Text("CANCEL"),
                            onPressed: () => Navigator.pop(context),
                          ),
                          TextButton(
                            child: const Text("TOKEN"),
                            onPressed: () =>
                                Navigator.pop(context, dialogController.text),
                          ),
                          TextButton(
                            child: const Text("URL"),
                            onPressed: () {
                              try {
                                Navigator.pop(
                                  context,
                                  Uri.parse(dialogController.text)
                                      .queryParameters["code"],
                                );
                              } on FormatException {
                                Navigator.pop(context);
                              }
                            },
                          )
                        ],
                      ),
                    );
                    if (code == null) {
                      return;
                    }
                    try {
                      final tokens = await malExchangeCode(client, code,
                          codeVerifier, data[TextFieldLabel.malClientId.name]!);
                      setState(() {
                        data[TextFieldLabel.malRefreshToken.name] =
                            tokens.refreshToken;
                        data[TextFieldLabel.malAccessToken.name] =
                            tokens.accessToken;
                        _saveToStorage();
                      });
                    } on HttpException catch (e) {
                      if (!mounted) return;
                      await errorDialog(context, e);
                    }
                  });
                },
                child: const Text("Auth MAL"),
              ),
              PopupMenuItem(
                child: const Text("Auth AniList"),
                onTap: () async {
                  aniListAuthorize(data[TextFieldLabel.anilistClientId.name]!);
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    dialogController.text = "";
                    final token = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        contentPadding: const EdgeInsets.all(8.0),
                        content: TextField(
                          controller: dialogController,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText:
                                  "Copy-paste the token/redirect URL here"),
                        ),
                        actions: [
                          TextButton(
                            child: const Text("CANCEL"),
                            onPressed: () => Navigator.pop(context),
                          ),
                          TextButton(
                            child: const Text("TOKEN"),
                            onPressed: () =>
                                Navigator.pop(context, dialogController.text),
                          ),
                          TextButton(
                            child: const Text("URL"),
                            onPressed: () {
                              try {
                                const key = 'access_token=';
                                final url = dialogController.text;
                                final idx = url.indexOf(key);
                                if (idx < 0) {
                                  return;
                                }
                                final fromTokenPart =
                                    url.substring(idx + key.length);
                                var ampersandIdx = fromTokenPart.indexOf("&");
                                if (ampersandIdx < 0) {
                                  ampersandIdx = fromTokenPart.length;
                                }

                                final token =
                                    fromTokenPart.substring(0, ampersandIdx);
                                Navigator.pop(context, token);
                              } on FormatException {
                                Navigator.pop(context);
                              }
                            },
                          )
                        ],
                      ),
                    );
                    if (token == null) {
                      return;
                    }
                    setState(() {
                      data[TextFieldLabel.anilistAccessToken.name] = token;
                      _saveToStorage();
                    });
                  });
                },
              ),
              PopupMenuItem(
                child: const Text("Open your NRS impl repo"),
                onTap: () async {
                  await launchUrlString(
                    data[TextFieldLabel.nrsImplGitRepoUri.name]!,
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              PopupMenuItem(
                child: const Text("Sync"),
                onTap: () async {
                  log("Loading AOD");
                  final aod = await loadAnimeOfflineDatabase(
                      cache, Uri.parse(data[TextFieldLabel.aodJsonUri.name]!));
                  log("Loading entries.json");
                  final entries = await loadNRSFilteredEntryList(cache,
                      Uri.parse(data[TextFieldLabel.entriesJsonUri.name]!));
                  log("Loading scores.json");
                  final scores = await loadNRSFilteredEntryList(cache,
                      Uri.parse(data[TextFieldLabel.scoresJsonUri.name]!));
                  log("Syncing MAL");
                  final malAuthData = data[TextFieldLabel.malAccessToken.name]!;
                  final alAuthData = AniListAuthData(
                      data[TextFieldLabel.anilistUsername.name]!,
                      data[TextFieldLabel.anilistAccessToken.name]!);
                  await sync(
                      aod, MAL(), client, entries, scores, malAuthData, log);
                  log("Syncing AniList");
                  await sync(
                      aod, AniList(), client, entries, scores, alAuthData, log);
                  log("Done");
                },
              ),
              PopupMenuItem(
                child: const Text("Reset cache"),
                onTap: () {
                  setState(() {
                    _clearStorage();
                  });
                },
              )
            ],
            tooltip: 'Do Stuff',
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.sync, size: 32.0, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}
