import 'package:bbmusic/origin_sdk/bili/utils.dart';
import 'package:bbmusic/origin_sdk/origin_types.dart';
import 'package:bbmusic/utils/clear_html_tags.dart';

/// 签名秘钥
class SignData {
  final String imgKey;
  final String subKey;

  const SignData({required this.imgKey, required this.subKey});

  factory SignData.fromJson(Map<String, dynamic> json) {
    String imgUrl = json['data']['wbi_img']['img_url'];
    String subUrl = json['data']['wbi_img']['sub_url'];
    String imgKey =
        imgUrl.substring(imgUrl.lastIndexOf('/') + 1, imgUrl.lastIndexOf('.'));
    String subKey =
        subUrl.substring(subUrl.lastIndexOf('/') + 1, subUrl.lastIndexOf('.'));
    return SignData(
      imgKey: imgKey,
      subKey: subKey,
    );
  }
}

/// Bilibili 网站 Cookie 中的 b_nut 字段
class BiliBNut {
  final String bNut;
  final String b3;

  const BiliBNut({required this.bNut, required this.b3});
}

/// 签名秘钥
class SpiData {
  final String b3;
  final String b4;

  const SpiData({required this.b3, required this.b4});

  factory SpiData.fromJson(Map<String, dynamic> json) {
    return SpiData(
      b3: json['data']['b_3'],
      b4: json['data']['b_4'],
    );
  }
}

/// 搜索结果
class BiliSearchResponse extends SearchResponse {
  BiliSearchResponse({
    required super.current,
    required super.total,
    required super.pageSize,
    required super.data,
  });
  /// 从 JSON 解析搜索结果
  /// 
  /// [json]: JSON 对象
  /// 
  /// 返回值：解析后的搜索结果对象
  factory BiliSearchResponse.fromJson(Map<String, dynamic> json) {
    // 解析 JSON 数据
    // 添加多种数据解析，目前仅支持视频和歌单
    // 后续添加合集解析
    // 不同的数据结构示例
    //
    // 关键字搜索结果
    // https://api.bilibili.com/x/web-interface/wbi/search/type
    // ['data']['result']
    // {'seid': '17667012750092474841', 'page': 1, 'pagesize': 20, 'numResults': 1000, 'numPages': 50, 'suggest_keyword': '', 'rqt_type': 'search', 'exp_list': {'100010': True, '5500': True, '6699': True}, 'is_hit_web_inf': False, 'egg_hit': 0, 'result': []}
    //
    // 单个合集搜索
    // https://api.bilibili.com/x/polymer/web-space/seasons_archives_list
    // ['data']['archives']
    // {'code': 0, 'message': 'OK', 'ttl': 1, 'data': {'aids': [], 'archives': [],'meta': {'category': 0, 'cover': '', 'description': '包括流行曲、ACG等歌曲的粤语二次填词创作。', 'mid': 78201, 'name': '合集·粤语翻唱精选', 'ptime': 1773117600, 'season_id': 13859, 'total': 47, 'title': '粤语翻唱精选'}, 'page': {'page_num': 1, 'page_size': 20, 'total': 47}}}
    //
    // UP所有合集和系列视频
    // https://api.bilibili.com/x/polymer/web-space/seasons_archives_list
    // ['data']['items_lists']
    // {'code': 0, 'message': 'OK', 'ttl': 1, 'data': {'items_lists': {'page': {'page_num': 1, 'page_size': 20, 'total': 10}, 'seasons_list': [],'series_list': [],'meta': {'category': 1, 'cover': '', 'creator': '', 'ctime': 1640253907, 'description': '', 'keywords': [''], 'last_update_ts': 1640253907, 'mid': 78201, 'mtime': 1640253907, 'name': 'Vocaloid系列粤语翻唱', 'raw_keywords': '', 'series_id': 1869390, 'state': 2, 'total': 17}, 'recent_aids': []}]}}}
    //
    // j
        // {'aid': 116143398325465, 'bvid': 'BV1zAADzPEsg', 'ctime': 1772207957, 'duration': 91, 'enable_vt': False, 'interactive_video': False, 'pic': 'http://i2.hdslb.com/bfs/archive/ef67d4a0c70ba08f2077c076937355b6b4c98e20.jpg', 'playback_position': 0, 'pubdate': 1772251800, 'stat': {'view': 335751, 'vt': 0, 'danmaku': 176}, 'state': 0, 'title': '放学ICU启动！看魔法少女就是要粤配！名侦探光之美少女ED粤语版', 'ugc_pay': 0, 'vt_display': '', 'is_lesson_video': 0}
        // meta
        // {'category': 0, 'cover': 'https://archive.biliimg.com/bfs/archive/a6df4b0fea842d2f26d4f742d7dbf9a222a506b8.jpg', 'description': '包括流行曲、ACG等歌曲的粤语二次填词创作。', 'mid': 78201, 'name': '合集·粤语翻唱精选', 'ptime': 1773117600, 'season_id': 13859, 'total': 47, 'title': '粤语翻唱精选'}
        //MusicItem
    //
    List<BiliSearchItem> data = [];
    List<MusicItem> musicList = [];
    //  条件判断语句，确保它们的类型正确。
    if (json['data']?['archives'] != null) {    // 单个合集
      // 单个合集搜索 列表名称
      // var result = json['data'] ?? {};
      //
      // data.add(BiliSearchItem.fromJson(result));
      // 这里是将输入data的解析为并显示所有视频
      // 单个合集或系列视频明细  
      // 遍历 archives 字段，解析每个视频项
      for (var j in json['data']['archives'].toList()??[]) {
        musicList = [];
        // 一个合集
        final String aid = j['aid'].toString();
        final String bvid = j['bvid'];
        String mmid = BiliId(aid: aid, bvid: bvid).decode();
        // 音乐项
        final item = MusicItem(
          id: mmid,
          cover: j['pic'] ?? "",
          name: clearHtmlTags(j['title']),
          duration: j['duration'] is String
            ? duration2seconds(j['duration'])
            : j['duration'],
          author: json['data']['meta']['mid']?.toString() ?? '',
          origin: OriginType.bili,
        );
        musicList.add(item);
        data.add(BiliSearchItem(
          id: mmid,
          cover: j['pic'] ?? "",
          name: clearHtmlTags(j['title']),
          duration: j['duration'] is String
            ? duration2seconds(j['duration'])
            : j['duration'],
          author: json['data']['meta']['mid']?.toString() ?? "",
          origin: OriginType.bili,
          type: SearchType.order,
          musicList: musicList,
        ));
        // 合集明细
        // data.add(BiliSearchItem(
        //   id: musicList.isNotEmpty ? musicList[0].id : '',
        //   cover: json['data']['meta']['cover'] ?? '',
        //   name: clearHtmlTags(json['data']['meta']['name'] ?? ''),
        //   duration: json['data']['meta']['total'] ?? 0,
        //   author: json['data']['meta']['mid']?.toString() ?? "",
        //   origin: OriginType.bili,
        //   type: SearchType.music,
        //   musicList: musicList,
        // ));
      }
      //
      return BiliSearchResponse(
        current: json['data']['page']['page_num'] ?? 0,
        total: json['data']['page']['total'] ?? 0,
        pageSize: json['data']['page']['page_size'] ?? 0,
        data: data,
        );
    } else if (json['data']?['items_lists'] != null) {    // UP所有合集和系列视频
      // UP所有合集 所有系列 视频 列表名称
      // var result = json['data'] ?? {};
      //
      // List<BiliSearchItem> data = [];
      // 合集
      // if (result['items_lists']?['seasons_list'] != null) {
      //   for (var j in result['items_lists']['seasons_list'].toList()) {
      //     data.add(BiliSearchItem.fromJson(j));
      //   }
      // }
      // // 系列
      // if (result['items_lists']?['series_list'] != null) {
      //   for (var j in result['items_lists']['series_list'].toList()) {
      //     data.add(BiliSearchItem.fromJson(j));
      //   }
      //
      // List<MusicItem> musicList = [];
      for (var selist in (json['data']['items_lists']['seasons_list'].toList()??[] + json['data']['items_lists']['series_list'].toList()??[])) {
        // data.add(BiliSearchItem.fromJson(j));
        for (var j in (selist['archives'].toList()??[])) {
          musicList = [];
          // 一个合集
          final String aid = j['aid'].toString();
          final String bvid = j['bvid'];
          String mmid = BiliId(aid: aid, bvid: bvid).decode();
          // 音乐项
          final item = MusicItem(
            id: mmid,
            cover: j['pic'] ?? "",
            name: clearHtmlTags(j['title']),
            duration: j['duration'] is String
              ? duration2seconds(j['duration'])
              : j['duration'],
            author: selist['meta']['mid']?.toString() ?? '',
            origin: OriginType.bili,
          );
          musicList.add(item);
          data.add(BiliSearchItem(
            id: mmid,
            cover: j['pic'] ?? "",
            name: clearHtmlTags(j['title']),
            duration: j['duration'] is String
              ? duration2seconds(j['duration'])
              : j['duration'],
            author: selist['meta']['mid']?.toString() ?? "",
            origin: OriginType.bili,
            type: SearchType.order,
            musicList: musicList,
          ));
          // 合集明细
          // data.add(BiliSearchItem(
          //   id: musicList.isNotEmpty ? musicList[0].id : '',
          //   cover: json['data']['meta']['cover'] ?? '',
          //   name: clearHtmlTags(json['data']['meta']['name'] ?? ''),
          //   duration: json['data']['meta']['total'] ?? 0,
          //   author: json['data']['meta']['mid']?.toString() ?? "",
          //   origin: OriginType.bili,
          //   type: SearchType.music,
          //   musicList: musicList,
          // ));
        }
      }
      //
      return BiliSearchResponse(
        current: json['data']['items_lists']['page']['page_num'] ?? 0,
        total: json['data']['items_lists']['page']['total'] ?? 0,
        pageSize: json['data']['items_lists']['page']['page_size'] ?? 0,
        data: data,
        );
    } else {
      // 关键字搜索结果
      // #if (json['data']?['result'] != null)
      var result = json['data']['result'].toList();
      List<BiliSearchItem> data = [];
      for (var j in result) {
        if (j['type'] != 'ketang') {
          data.add(BiliSearchItem.fromJson(j));
        }
      }
      return BiliSearchResponse(
        current: json['data']['page'],
        total: json['data']['numResults'],
        pageSize: json['data']['pagesize'],
        data: data,
      );
    }
  }
}

// 搜索条目详情
class BiliSearchItem extends SearchItem {
  const BiliSearchItem({
    required super.id,
    required super.cover,
    required super.name,
    required super.duration,
    required super.author,
    required super.origin,
    super.musicList,
    super.type,
  });
  factory BiliSearchItem.fromJson(Map<String, dynamic> json) {
    // 检查是否存在 archives 字段，判断是否为合集搜索
    // if (json['archives'] != null){
    //   // 单个合集
    //   List<MusicItem> musicList = [];
    //   // 只需要合集名称了
    //   // 遍历 archives 字段，解析每个视频项
    //   // for (var j in json['archives'].toList()) {
    //   //   // 一个合集
    //   //   final String aid = j['aid'].toString();
    //   //   final String bvid = j['bvid'];
    //   //   String mmid = BiliId(aid: aid, bvid: bvid, cid: j['cid']?.toString()).decode();
    //   //   // 音乐项
    //   //   final item = MusicItem(
    //   //     id: mmid,
    //   //     cover: j['pic'] ?? "",
    //   //     name: clearHtmlTags(j['title']),
    //   //     duration: j['duration'] is String
    //   //       ? duration2seconds(j['duration'])
    //   //       : j['duration'],
    //   //     author: json['meta']['mid']?.toString() ?? '',
    //   //     origin: OriginType.bili,
    //   //   );
    //   //   musicList.add(item);
    //   // }
    //   // 合集 和 系列
    //   // 合集信息:{'category': 0, 'cover': 'https://archive.biliimg.com/bfs/archive/22119bdf85bb8fac674f39549775cf8015024e7f.jpg', 'description': '收录岗老师原创歌和人声本家，如有缺漏可以私信提醒哦！', 'mid': 78201, 'name': '合集·岗老师原创系列', 'ptime': 1734260100, 'season_id': 4190520, 'total': 16, 'title': '岗老师原创系列'}
    //   // 系列信息:{'category': 1, 'cover': 'http://i2.hdslb.com/bfs/archive/b02daf3a32266888d9f3bd09b638d8b4bdf6fc03.jpg', 'creator': '', 'ctime': 1640253907, 'description': '', 'keywords': [''], 'last_update_ts': 1688782536, 'mid': 78201, 'mtime': 1688782536, 'name': '流行歌曲粤语翻唱', 'raw_keywords': '', 'series_id': 1869391, 'state': 2, 'total': 65}
    //   if (json['meta']['category'] == 1) {
    //     // 系列  向后传输一个特殊的id 在处理视频详情时 用于区分系列和合集
    //     return BiliSearchItem(
    //       id: (json['meta']['mid']?.toString() ?? "") + '_' + (json['meta']['season_id']?.toString() ?? "")+ '_' + (json['meta']['total']?.toString() ?? "") + '_1',
    //       cover: json['meta']['cover'] ?? '',
    //       name: clearHtmlTags(json['meta']['name'] ?? ''),
    //       duration: json['meta']['total'] ?? 0,
    //       author: json['meta']['mid']?.toString() ?? "",
    //       origin: OriginType.bili,
    //       type: SearchType.order,
    //       musicList: musicList,
    //     );
    //   } else {
    //     // 合集 向后传输一个特殊的id 在处理视频详情时 用于区分系列和合集
    //     return BiliSearchItem(
    //       id: (json['meta']['mid']?.toString() ?? "") + '_' + (json['meta']['season_id']?.toString() ?? "") + '_' + (json['meta']['total']?.toString() ?? "") + '_0',
    //       cover: json['meta']['cover'] ?? '',
    //       name: clearHtmlTags(json['meta']['name'] ?? ''),
    //       duration: json['meta']['total'] ?? 0,
    //       author: json['meta']['mid']?.toString() ?? "",
    //       origin: OriginType.bili,
    //       type: SearchType.order,
    //       musicList: musicList,
    //     );
    //   }
    // } if (json['data'] != null) {
    //   // 这里是将输入data的解析为并显示所有视频
    //   // 单个合集或系列视频明细  
    //   List<MusicItem> musicList = [];
    //   // 遍历 archives 字段，解析每个视频项
    //   for (var j in json['data']['archives'].toList()) {
    //     // 一个合集
    //     final String aid = j['aid'].toString();
    //     final String bvid = j['bvid'];
    //     String mmid = BiliId(aid: aid, bvid: bvid).decode();
    //     // 音乐项
    //     final item = MusicItem(
    //       id: mmid,
    //       cover: j['pic'] ?? "",
    //       name: clearHtmlTags(j['title']),
    //       duration: j['duration'] is String
    //         ? duration2seconds(j['duration'])
    //         : j['duration'],
    //       author: json['data']['meta']['mid']?.toString() ?? '',
    //       origin: OriginType.bili,
    //     );
    //     musicList.add(item);
    //   }
    //   // 合集明细
    //   return BiliSearchItem(
    //     id: musicList.isNotEmpty ? musicList[0].id : '',
    //     cover: json['data']['meta']['cover'] ?? '',
    //     name: clearHtmlTags(json['data']['meta']['name'] ?? ''),
    //     duration: json['data']['meta']['total'] ?? 0,
    //     author: json['data']['meta']['mid']?.toString() ?? "",
    //     origin: OriginType.bili,
    //     type: SearchType.order,
    //     musicList: musicList,
    //   );
    // } else {
    //   final String aid = json['aid'].toString();
    //   final String bvid = json['bvid'];
    //   String id = BiliId(aid: aid, bvid: bvid).decode();

    //   SearchType? type;
    //   List<MusicItem> musicList = [];

    //   // 判断是否为歌单
    //   // "videos": 20, // 表示该视频是一个合集（歌单）
    //   if (json['videos'] != null) {    // 歌单
    //     type = SearchType.order;
    //     final pages = json['pages'].toList();

    //     for (var j in pages) {
    //       final mmid = BiliId(
    //         aid: aid,
    //         bvid: bvid,
    //         cid: j['cid']?.toString(),
    //       ).decode();

    //       final item = MusicItem(
    //         id: mmid,
    //         cover: j['first_frame'] ?? "",
    //         name: j['part'],
    //         duration: j['duration'],
    //         author: '',
    //         origin: OriginType.bili,
    //       );
    //       musicList.add(item);
    //     }
    //   }
    //   if (musicList.isNotEmpty) {
    //     if (json['videos'] > 1) {
    //       type = SearchType.order;
    //     } else {
    //       type = SearchType.music;
    //       id = musicList[0].id;
    //     }
    //   }

    //   return BiliSearchItem(
    //     id: id,
    //     cover: json['pic'],
    //     name: clearHtmlTags(json['title']),
    //     duration: json['duration'] is String
    //         ? duration2seconds(json['duration'])
    //         : json['duration'],
    //     author: json['author'] ?? "",
    //     origin: OriginType.bili,
    //     type: type,
    //     musicList: musicList,
    //   );
    // }
    //
    final String aid = json['aid'].toString();
    final String bvid = json['bvid'];
    String id = BiliId(aid: aid, bvid: bvid).decode();

    SearchType? type;
    List<MusicItem> musicList = [];
    MusicItem? item;
    String mmid;
    String typeSerList = '0';  // 0  默认值;  1 歌单 ; 2 合集 优先判断为合集。

    if ((json['ugc_season'] != null) && ((json['ugc_season']?['ep_count']??0) > 1)) {    // 合集
      typeSerList = '2';
    } else {
      if (json['videos'] != null) {    // 歌单
        typeSerList = '1';
      }
    }
    //
    switch(typeSerList){
      case '1':
        // "videos": 20, // 表示该视频是一个歌单
        if (json['videos'] != null) {    // 歌单
          type = SearchType.order;
          final pages = json['pages'].toList() ?? [];

          for (var j in pages) {
            mmid = BiliId(
              aid: aid,
              bvid: bvid,
              cid: j['cid']?.toString(),
            ).decode();
            //
            item = MusicItem(
              id: mmid,
              cover: j['first_frame'] ?? "",
              name: j['part'],
              duration: j['duration'],
              author: '',
              origin: OriginType.bili,
            );
            musicList.add(item);
          }
        }
        break;
      case '2':
        // 添加搜索的歌曲到第一个
        if (json['videos'] != null) {    // 歌单
          type = SearchType.order;
          final pages = json['pages'].toList() ?? [];

          for (var j in pages) {
            mmid = BiliId(
              aid: aid,
              bvid: bvid,
              cid: j['cid']?.toString(),
            ).decode();
            //
            item = MusicItem(
              id: mmid,
              cover: j['first_frame'] ?? "",
              name: j['part'],
              duration: j['duration'],
              author: '',
              origin: OriginType.bili,
            );
            musicList.add(item);
          }
        }
        // 合集 ugc_season	obj	视频合集信息
        if (json['ugc_season'] != null) {    // 合集
          type = SearchType.order;
          final sections = json['ugc_season']['sections'].toList() ?? [];
          // 遍历 ugc_season 字段，解析每个视频项
          for (var epj in sections) {
            for (var j in (epj['episodes'].toList() ?? [])) {
              mmid = BiliId(
              aid: j['aid'].toString(),
              bvid: j['bvid'],
              cid: j['cid']?.toString(),
            ).decode();
            //
            item = MusicItem(
              id: mmid,
              cover: j['arc']['pic'] ?? "",
              name: j['title'] ?? "",
              duration: j['arc']['duration'] ?? 0,
              author: j['arc']['author']['name'] ?? '',
              origin: OriginType.bili,
            );
            musicList.add(item);
          }}
        }
        break;
      default:
        break;
    }
    //
    if (musicList.isNotEmpty) {
      if (((typeSerList == '1') &&((json['videos'] ?? 0) > 1)) || ((typeSerList == '2') &&((json['ugc_season']['ep_count'] ?? 0) > 1))) {
        type = SearchType.order;
      } else {
        type = SearchType.music;
        id = musicList[0].id;
      }
    }
    //
    // if (musicList.isNotEmpty) {
    //   if ((json['videos'] ?? 0) > 1) {
    //     type = SearchType.order;
    //   } else {
    //     type = SearchType.music;
    //     id = musicList[0].id;
    //   }
    // }
    
    return BiliSearchItem(
      id: id,
      cover: json['pic'],
      name: clearHtmlTags(json['title']),
      duration: json['duration'] is String
          ? duration2seconds(json['duration'])
          : json['duration'],
      author: json['author'] ?? "",
      origin: OriginType.bili,
      type: type,
      musicList: musicList,
    );
  }
}

class BiliMusicDetail extends MusicDetail {
  BiliMusicDetail({
    required super.id,
    required super.cover,
    required super.name,
    required super.duration,
    required super.author,
    required super.origin,
    required super.url,
  });

  factory BiliMusicDetail.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    return BiliMusicDetail(
      id: id,
      cover: json['first_frame'],
      name: json['part'],
      duration: json['duration'],
      author: '',
      origin: OriginType.bili,
      url: '',
    );
  }
}
