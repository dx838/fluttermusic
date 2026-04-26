import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:bbmusic/origin_sdk/bili/utils.dart';
import 'package:bbmusic/utils/logs.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../origin_types.dart';
import './sign.dart';
import './types.dart';
import './ticket.dart';

const _userAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
const _referer = "https://www.bilibili.com/";
const _cacheCreatedAtKey = "bili_catch_created_at";
const _signImgKey = "bili_sign_img_key";
const _signSubKey = "bili_sign_sub_key";
const _ticketKey = "bili_ticket";
const _spiB3 = "bili_spi_b3";
const _spiB4 = "bili_spi_b4";
const _cacheVersionKey = 'bili_cache_version';
const _cacheVersionValue = '4';
//
const _headersAccept = "application/json, text/plain, */*";
const _headersAcceptLanguage = "zh-CN,zh;q=0.9";

class BiliClient implements OriginService {
  final dio = Dio();

  SignData? signData;
  SpiData? spiData;
  String? ticket;
  String? bNut;

  // bNut 缓存
  BiliBNut? _bNutCache;
  DateTime? _bNutCacheTime;

  BiliClient() {
    dio.options.headers["UserAgent"] = _userAgent;
    dio.options.headers["Referer"] = _referer;
    dio.options.headers["Accept"] = _headersAccept;
    dio.options.headers["Accept-Language"] = _headersAcceptLanguage;
    // dio.options.headers['Origin'] = "https://space.bilibili.com";
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final cookies = [
            // "buvid4=${spiData?.b4};",
            // "buvid3=${spiData?.b3};",
          ];
          if (options.uri.path.startsWith("/x/player/wbi/playurl")) {
            // cookies.add("bili_ticket=$ticket;");
          } else {
            cookies.add("buvid4=${spiData?.b4};");
            cookies.add("buvid3=${spiData?.b3};");
            cookies.add("bili_ticket=$ticket;");
            cookies.add("b_nut=$bNut;");
            final cookie = cookies.join(" ");
            logs.i('Cookie: ', error: {"Cookie": cookie});
            options.headers["cookie"] = cookie;
          }
          // cookies.add("buvid4=${spiData?.b4};");
          // cookies.add("buvid3=${spiData?.b3};");
          // cookies.add("bili_ticket=$ticket;");
          // cookies.add("b_nut=$bNut;");
          logs.i('OnRequest:', error: {
            "path": options.uri.path,
            "url": options.uri.toString(),
            "Cookie": options.headers["cookie"],
          });
          return handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) {
          // BotToast.showText(text: '请求失败: $error');
          return handler.next(error);
        },
        onResponse: (Response response, ResponseInterceptorHandler handler) {
          final logData = {
            "requestOptions": response.requestOptions,
            "url": response.realUri.toString(),
            "data": response.data,
            "statusCode": response.statusCode,
          };
          logs.i("bili: OnResponse", error: logData);
          if (response.realUri.toString().contains('x/web-interface/nav')) {
            return handler.next(response);
          }
          // 处理错误状态码
          if (response.statusCode! < 200 || response.statusCode! > 300) {
            BotToast.showText(
                text:
                    '资源请求失败: ${response.statusCode} ${response.statusMessage} ${response.data}');
            throw DioException(
              requestOptions: response.requestOptions,
              response: response,
              error: logData,
              type: DioExceptionType.badResponse,
            );
          }

          if (response.data is! Map) {
            return handler.next(response);
          }

          final code = response.data['code'];
          final message = response.data['message'];
          final resData = response.data['data'];

          if (code != 0) {
            BotToast.showText(text: '请求失败: $message');
            logs.e(
              'bili: 请求失败',
              error: logData,
            );
            throw DioException(
              requestOptions: response.requestOptions,
              response: response,
              error: logData,
              type: DioExceptionType.badResponse,
            );
          }
          if (resData['v_voucher'] != null) {
            BotToast.showText(text: '请求失败，触发风控，请稍后重试');
            logs.e(
              'bili: 请求失败, 触发风控',
              error: logData,
            );
            throw DioException(
              requestOptions: response.requestOptions,
              response: response,
              error: logData,
              type: DioExceptionType.badResponse,
            );
          }
          return handler.next(response);
        },
      ),
    );
  }

  init() async {
    final localStorage = await SharedPreferences.getInstance();
    final createAt = localStorage.getInt(_cacheCreatedAtKey);
    final cacheVersion = localStorage.getString(_cacheVersionKey);
    final bNutItem = await getBNut();
    bNut = bNutItem?.bNut;

    if (createAt != null && cacheVersion == _cacheVersionValue) {
      // 判断是否过期
      final isExpired = DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(createAt))
              .inDays >
          1;
      if (!isExpired) {
        final signImgKey = localStorage.getString(_signImgKey);
        final signSubKey = localStorage.getString(_signSubKey);
        final spiB3 = localStorage.getString(_spiB3);
        final spiB4 = localStorage.getString(_spiB4);
        final ticketCache = localStorage.getString(_ticketKey);
        if (signSubKey != null &&
            signImgKey != null &&
            spiB3 != null &&
            spiB4 != null &&
            ticketCache != null &&
            ticketCache.isNotEmpty) {
          signData = SignData(imgKey: signImgKey, subKey: signSubKey);
          spiData = SpiData(b3: bNutItem?.b3 ?? spiB3, b4: spiB4);
          ticket = ticketCache;
          return;
        }
      }
    }
    try {
      final results = await Future.wait([
        getSignData(),
        getSpiData(),
        getBiliTicket(""),
      ]);
      signData = results[0] as SignData;
      spiData = results[1] as SpiData;
      ticket = results[2] as String;
      if (bNutItem?.b3.isNotEmpty == true && spiData!.b3.isNotEmpty) {
        spiData = SpiData(b3: bNutItem!.b3, b4: spiData!.b4);
      }

      localStorage.setString(_cacheVersionKey, _cacheVersionValue);

      localStorage.setInt(
        _cacheCreatedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      if (ticket != null || ticket!.isNotEmpty) {
        localStorage.setString(_ticketKey, ticket!);
      }
      if (signData != null) {
        localStorage.setString(_signImgKey, signData!.imgKey);
        localStorage.setString(_signSubKey, signData!.subKey);
      }
      if (spiData != null) {
        localStorage.setString(_spiB3, spiData!.b3);
        localStorage.setString(_spiB4, spiData!.b4);
      }
    } catch (e) {
      logs.e("bili: 认证初始化失败", error: e);
    }
  }

  // 获取签名秘钥
  Future<SignData> getSignData() async {
    final response =
        await dio.get("https://api.bilibili.com/x/web-interface/nav");

    if (response.statusCode == 200) {
      return SignData.fromJson(response.data);
    } else {
      logs.e("bili: 获取签名秘钥失败", error: {"body": response.data});
      throw response.data;
    }
  }

  // 获取 spi 唯一标识
  Future<SpiData> getSpiData() async {
    final response =
        await dio.get("https://api.bilibili.com/x/frontend/finger/spi");

    if (response.statusCode == 200) {
      return SpiData.fromJson(response.data);
    } else {
      logs.e("bili: 获取 spi 唯一标识失败", error: {"body": response.data});
      throw response.data;
    }
  }

  // 获取 b_nut
  Future<BiliBNut?> getBNut() async {
    if (_bNutCache != null &&
        _bNutCacheTime != null &&
        DateTime.now().difference(_bNutCacheTime!).inSeconds < 1) {
      return _bNutCache;
    }
    final response = await Dio().get("https://www.bilibili.com/");
    if (response.statusCode == 200) {
      // 获取响应头中的 Set-Cookie 字段中 的 b_nut
      final setCookie = response.headers["Set-Cookie"];
      final b3Item =
          setCookie?.firstWhere((element) => element.startsWith("buvid3"));
      final b3 = b3Item?.split(";")[0].split("=")[1] ?? "";
      final bNutItem =
          setCookie?.firstWhere((element) => element.startsWith("b_nut"));
      final nNut = bNutItem?.split(";")[0].split("=")[1] ?? "";

      _bNutCache = BiliBNut(bNut: nNut, b3: b3);
      _bNutCacheTime = DateTime.now();
      return _bNutCache;
    }
    return null;
  }

  // 搜索
  @override
  Future<SearchResponse> search(SearchParams params) async {
    // 单个合集
    //
    // UP所有合集
    //
    // 关键词搜索
    await init();
    RegExp? strRegex;
    RegExpMatch? match;
    String? vType = '0';  // 视频类型标记
    // 0: 默认 歌单
    // 1: 单个合集
    // 2: 合集和系列视频
    // 3: UP 单个系列视频
    // 4: UP 系列视频
    String? uid;
    String? fid;
    String url = 'https://api.bilibili.com/x/web-interface/wbi/search/type';
    
    // 单个合集
    strRegex = RegExp(r'space\.bilibili\.com/(\d+)/lists/(\d+)');
    match = strRegex.firstMatch(params.keyword);
    if (match != null) {
      uid = match.group(1) ?? '';  // up id
      fid = match.group(2) ?? '';  // 合集 id
      // BotToast.showText(
      //           text: 'List uid: $uid, fid: $fid');
      vType = '1';
    } else {
      // up所有合集 和 系列视频
      strRegex = RegExp(r'bilibili\.com/(\d+)/');
      match = strRegex.firstMatch(params.keyword);
      if (match != null) {
        uid = match.group(1) ?? '';
        // BotToast.showText(
        //           text: 'AllList uid_t: $uid_t');
        vType = '2';
      } else {
        // UP 系列视频
        // 整个系列 https://www.bilibili.com/list/78201/?oid=116386701511292&bvid=BV1eWDyBGE7f
        // API     https://api.bilibili.com/x/polymer/web-space/home/seasons_series
        //
        // 单个系列 https://www.bilibili.com/list/78201/?sid=1869393
        // API     https://api.bilibili.com/x/series/archives
        strRegex = RegExp(r'bilibili\.com/list/(\d+)/\?sid=(\d+)');
        match = strRegex.firstMatch(params.keyword);
        if (match != null) {
          uid = match.group(1) ?? '';
          fid = match.group(2) ?? '';
          vType = '3';
        } else {
          strRegex = RegExp(r'bilibili\.com/list/(\d+)/');
          match = strRegex.firstMatch(params.keyword);
          if (match != null) {
            uid = match.group(1) ?? '';
            vType = '4';
          }
        }
      }
    }
    // 单个合集
    //
    Map<String, String> query;
    // 
    switch(vType){
      case '1':
        // 单个合集
        url = 'https://api.bilibili.com/x/polymer/web-space/seasons_archives_list';
        query = _signParams({
          'mid': uid.toString() ?? '',          // 字符串 
          'season_id': fid.toString() ?? '',    // 字符串
          'page_num': params.page.toString(),
          'page_size': '20',
        });
        break;
      case '2':
        // UP所有合集 和 系列视频
        url = 'https://api.bilibili.com/x/polymer/web-space/seasons_series_list';
        query = _signParams({
          'mid': uid.toString() ?? '',    // 字符串
          'page_num': params.page.toString(),
          'page_size': '20',
        });
        break;
      case '3':
        // UP 单个系列视频
        url = 'https://api.bilibili.com/x/series/archives';
        query = _signParams({
          'mid': uid.toString() ?? '',          // 字符串 
          'season_id': fid.toString() ?? '',    // 字符串
          'pn': params.page.toString(),
          'ps': '20',
          'sort': 'asc',
          'only_normal': 'true',
        });
        break;
      case '4':
        // UP 系列视频
        url = 'https://api.bilibili.com/x/polymer/web-space/home/seasons_series';
        query = _signParams({
          'mid': uid.toString() ?? '',          // 字符串 
          'season_id': fid.toString() ?? '',    // 字符串
          'page_num': params.page.toString(),
          'page_size': '20',
        });
        break;
      default:
        // 关键词搜索
        url = 'https://api.bilibili.com/x/web-interface/wbi/search/type';
        query = _signParams({
          'search_type': 'video',
          'keyword': params.keyword,
          'page': params.page.toString(),
          'pagesize': '20',
        });
        break;
    }
    // 构建 API 路径
    final apiPath = Uri.parse(url).replace(queryParameters: query).toString();
    try {
      // 单个合集
      //
      // UP所有合集
      //
      // 关键词搜索
      final response = await dio.get(apiPath);
      // 打印响应数据
      // BotToast.showText(
      //             text: 'Search response: $response');
      // 打印请求后的数据
      // final searchResponse = BiliSearchResponse.fromJson(response.data);
      // String logMessage = "BiliSearchResponse: current=${searchResponse.current}, total=${searchResponse.total}, pageSize=${searchResponse.pageSize}, dataLength=${searchResponse.data.length}\n";
      // // 添加详细数据
      // for (int i = 0; i < searchResponse.data.length; i++) {
      //   final item = searchResponse.data[i];
      //   logMessage += "Item $i: id=${item.id}, name=${item.name}, author=${item.author}, type=${item.type}\n";
      // }
      // BotToast.showText(text: logMessage);
      // 解析 JSON 数据
      // search 关键字搜索示例
      // {'type': 'video', 'id': 1388071, 'author': 'hanser', 'mid': 11073, 'typeid': '31', 'typename': '翻唱', 'arcurl': 'http://www.bilibili.com/video/av1388071', 'aid': 1388071, 'bvid': 'BV1Sx411N7yz', 'title': '警察蜀黍!!!就是这个人!!!! 翻唱', 'description': '原曲 av1328642  映画:PROJECT_ZYL 怪蜀黍+作曲:DMYOUNG 。原曲一听就停不下来了。 mp3：http://5sing.kugou.com/fc/13260230.html 。燃不起来的p2当赠品 mp3：http://5sing.kugou.com/fc/13219519.html', 'pic': '//i0.hdslb.com/bfs/archive/be8a3db33f21183539909c88d32bd088d0caac92.jpg', 'play': 2280610, 'video_review': 20688, 'favorites': 46343, 'tag': 'ZYL,UNRAVEL', 'review': 3067, 'pubdate': 1407465284, 'senddate': 1613897682, 'duration': '4:18', 'badgepay': False, 'hit_columns': ['author'], 'view_type': '', 'is_pay': 0, 'is_union_video': 0, 'rec_tags': None, 'new_rec_tags': [], 'like': 35231, 'upic': 'https://i0.hdslb.com/bfs/face/0d179321aca5adc3a18f5e257c2f8ada1956063b.jpg', 'corner': '', 'cover': '', 'desc': '', 'url': '', 'rec_reason': '', 'danmaku': 20688, 'biz_data': None, 'is_charge_video': 0, 'vt': 0, 'enable_vt': 0, 'vt_display': '', 'subtitle': '', 'episode_count_text': '', 'release_status': 0, 'is_intervene': 0, 'area': 0, 'style': 0, 'cate_name': '', 'is_live_room_inline': 0, 'live_status': 0, 'live_time': '', 'online': 0, 'rank_index': 5, 'rank_offset': 5, 'roomid': 0, 'short_id': 0, 'spread_id': 0, 'tags': '', 'uface': '', 'uid': 0, 'uname': '', 'user_cover': '', 'parent_area_id': 0, 'parent_area_name': '', 'watched_show': None, 'cny_flag': 0, 'card_status': 0}
      // logs.i("bili: 搜索成功", error: {"body": response.data});
      return BiliSearchResponse.fromJson(response.data);
    } catch (e) {
      return BiliSearchResponse(
        current: 0,
        total: 0,
        pageSize: 0,
        data: [],
      );
    }
  }

  // 搜索条目详情
  @override
  Future<SearchItem> searchDetail(String id) async {
    // 处理歌单详情  单个合集 UP所有合集应该也是来这里处理
    // 歌单
    // https://api.bilibili.com/x/web-interface/view
    // 合集
    // https://api.bilibili.com/x/polymer/web-space/seasons_archives_list
    //
    // await init();
    //
    // Map<String, String> query;
    // String url;
    // Response response;
    // Map<String, dynamic> data = {};
    //
    // final RegExp uidsidRegex = RegExp(r'(\d+)_(\d+)_(\d+)_(\d+)');
    // final match = uidsidRegex.firstMatch(id);
    // if (match != null) {
    //   final uid = match.group(1) ?? '';  // up id
    //   final sid = match.group(2) ?? '';  // 合集 id
    //   final total = match.group(3) ?? '0';  // 总集数
    //   final category = match.group(4) ?? '';  // 类型
    // }
    // if (category == '1') {
    //   // 系列
    //   url = 'https://api.bilibili.com/x/series/archives';
    //   // 获取所有视频数据
    //   final totalPage = ((int.tryParse(biliid.cid) ?? 0) / 20).ceil();
    //   // 遍历所有页面
    //   for (int i = 1; i <= totalPage; i++) {
    //     final page = i;
    //     query = _signParams({
    //       'mid': biliid.aid.toString() ?? '',          // 字符串 
    //       'series_id': biliid.cid.toString() ?? '',    // 系列ID
    //       'pn': page.toString()??'1',
    //       'ps': '20',
    //     });
    //     response = await dio.get(
    //       Uri.parse(url).replace(queryParameters: query).toString(),
    //     );
    //     // 如果 data 为空，跳过
    //       if (data['data'] == null) {
    //         data = response.data;
    //       } else {
    //       // 合并数据
    //         data['data']['archives'].addAll(response.data['data']['archives']);
    //       }
    //     }
    // } else if (category == '0') {
    //     // 合集
    //     url = 'https://api.bilibili.com/x/polymer/web-space/seasons_archives_list';
    //     // 获取所有视频数据
    //     final totalPage = ((int.tryParse(biliid.cid) ?? 0) / 20).ceil();
    //     // 遍历所有页面
    //     for (int i = 1; i <= totalPage; i++) {
    //       final page = i;
    //       query = _signParams({
    //         'mid': biliid.aid.toString() ?? '',          // 字符串 
    //         'season_id': sid.toString() ?? '',    // 合集
    //         'page_num': page.toString()??'1',
    //         'page_size': '20',
    //       });
    //       response = await dio.get(
    //         Uri.parse(url).replace(queryParameters: query).toString(),
    //       );
    //       // 如果 data 为空，跳过
    //       if (data['data'] == null) {
    //         data = response.data;
    //       } else {
    //       // 合并数据
    //         data['data']['archives'].addAll(response.data['data']['archives']);
    //       }
    //     }
    //   //
    //   // query = _signParams({
    //   //   'mid': uid.toString() ?? '',          // 字符串 
    //   //   'season_id': sid.toString() ?? '',    // 字符串
    //   //   'page_num': params.page.toString()??'1',
    //   //   'page_size': '20',
    //   // });
    //   // response = await dio.get(
    //   //   Uri.parse(url).replace(queryParameters: query).toString(),
    //   // );
    //   // data = response.data;
    //   // 
    //   // return BiliSearchItem.fromJson(data);
    // } else {
    //   // 歌单
    //   BiliId biliid = BiliId.unicode(id);
      
    //   url = 'https://api.bilibili.com/x/web-interface/view';
    //   query = _signParams({
    //     'aid': biliid.aid,
    //     'bvid': biliid.bvid,
    //   });
    //   response = await dio.get(
    //     Uri.parse(url).replace(queryParameters: query).toString(),
    //   );
    //   data = response.data['data'];
    //   // 详情日志
    //   // BotToast.showText(
    //   //               text: 'searchDetail response: $data');
    //   // logs.i("bili: 搜索条目详情成功", error: {"body": data});
    //   // return BiliSearchItem.fromJson(data);
    // }
    
    BiliId biliid = BiliId.unicode(id);
    await init();
    final url = 'https://api.bilibili.com/x/web-interface/view';
    Map<String, String> query = _signParams({
      'aid': biliid.aid,
      'bvid': biliid.bvid,
    });
    final response = await dio.get(
      Uri.parse(url).replace(queryParameters: query).toString(),
    );
    final data = response.data['data'];
    // BotToast.showText(text: 'searchDetail response: $data');
    // // // 打印请求后的数据
    // final item = BiliSearchItem.fromJson(data);
    // // 构建日志消息
    // String logMessage = "BiliSearchItem: id=${item.id}, name=${item.name}, author=${item.author}, type=${item.type}, duration=${item.duration}, cover=${item.cover}\n";
    
    // // 添加音乐列表信息
    // logMessage += "MusicList length: ${item.musicList?.length ?? 0}\n";

    // if (item.musicList != null) {
    //   for (int i = 0; i < item.musicList!.length; i++) {
    //     final music = item.musicList![i];
    //     logMessage += "Music $i: id=${music.id}, name=${music.name}, duration=${music.duration}, cover=${music.cover}\n";
    //   }
    // }
    // BotToast.showText(text: logMessage);
    //
    //
    try {
      return BiliSearchItem.fromJson(data);
    } catch (e) {
      BotToast.showText(text: 'searchDetail fromJson: $e');
      return BiliSearchItem(
      id: '',
      cover: '',
      name: '',
      duration: 0,
      author: '',
      origin: OriginType.bili,
      type: SearchType.music,
      musicList: [],
      );
    }
    
  }

  // 搜索建议
  @override
  Future<List<SearchSuggestItem>> searchSuggest(String keyword) async {
    await init();
    const url = 'https://s.search.bilibili.com/main/suggest';
    Map<String, String> query = _signParams({
      'term': keyword,
    });
    final response = await dio.get(url, queryParameters: query);

    if (response.statusCode == 200) {
      final data =
          response.data is String ? jsonDecode(response.data) : response.data;
      final List<dynamic> tags = data['result']['tag'];
      List<SearchSuggestItem> result = [];
      tags.toList().forEach((t) {
        result.add(SearchSuggestItem(name: t['name'], value: t['value']));
      });
      return result;
    } else {
      logs.e(
        "bili: 搜索条目详情获取失败",
        error: {"body": response.data, 'keyword': keyword},
      );
      throw response.data;
    }
  }

  // 获取音乐播放地址
  @override
  Future<MusicUrl> getMusicUrl(String id) async {
    BiliId biliid = BiliId.unicode(id);
    if (biliid.cid == null || biliid.cid == '') {
      // 歌曲 ID 不正确 缺少 CID
      logs.e("bili: 歌曲 ID 不正确 缺少 CID", error: {
        "id": id,
        "biliid": biliid,
      });
      throw Exception('歌曲 ID 不正确 缺少 CID');
    }
    await init();
    const apiPath = 'https://api.bilibili.com/x/player/wbi/playurl';
    // const url = 'https://api.bilibili.com/x/player/playurl';
    Map<String, String> query = _signParams({
      'avid': biliid.aid,
      'bvid': biliid.bvid,
      'cid': biliid.cid!,
      'fnval': '16',
    });
    final uri = Uri.parse(apiPath).replace(queryParameters: query).toString();
    final response = await dio.get(uri);
    final data = response.data['data'];
    List<dynamic> audioList = data['dash']?['audio']?.toList() ?? [];
    if (audioList.isEmpty) {
      logs.e(
        "bili: 音频列表为空",
        error: {"body": response.data, 'id': id},
      );
      throw response.data;
    }
    // 排序，取带宽最大的音质最高
    audioList.sort((a, b) => b['bandwidth'].compareTo(a['bandwidth']));
    String murl = audioList[0]['baseUrl'];
    return MusicUrl(
      url: murl,
      headers: {'Referer': _referer},
    );
  }

  // 对参数进行签名
  _signParams(Map<String, String> params) {
    if (signData == null) {
      throw Exception('请先获取签名秘钥');
    }
    return encWbi(params, signData!.imgKey, signData!.subKey);
  }
}
