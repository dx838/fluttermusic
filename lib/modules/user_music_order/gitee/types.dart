import 'dart:convert';

import 'package:bbmusic/origin_sdk/origin_types.dart';

class GiteeFile {
  String name;
  String path;
  String sha;
  int size;
  String url;
  String htmlUrl;
  String downloadUrl;
  String type;
  List<MusicOrderItem> content;
  String encoding;

  GiteeFile({
    required this.name,
    required this.path,
    required this.sha,
    required this.size,
    required this.url,
    required this.htmlUrl,
    required this.downloadUrl,
    required this.type,
    required this.content,
    required this.encoding,
  });

  factory GiteeFile.fromJson(Map<String, dynamic> json) {
    return GiteeFile(
      name: json['name'],
      path: json['path'],
      sha: json['sha'],
      size: json['size'],
      url: json['url'],
      htmlUrl: json['html_url'],
      downloadUrl: json['download_url'],
      type: json['type'],
      content: decodeGiteeFileContent(json['content']),
      encoding: json['encoding'],
    );
  }
}

List<MusicOrderItem> decodeGiteeFileContent(String content) {
  final contentRaw = content.replaceAll('\n', '');
  String raw = const Utf8Decoder().convert(base64Decode(contentRaw));
  final data = json.decode(raw.trim().isEmpty ? '[]' : raw);
  List<MusicOrderItem> list = [];
  for (var item in data) {
    list.add(
      MusicOrderItem.fromJson(item),
    );
  }
  return list;
}
