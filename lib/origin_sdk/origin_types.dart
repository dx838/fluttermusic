/// 搜索结果类型枚举
/// 
/// 定义了两种搜索结果类型：
/// - order: 歌单
/// - music: 歌曲
enum SearchType {
  order(value: 'order', name: '歌单'),
  music(value: 'music', name: '歌曲');

  /// 构造函数
  /// 
  /// [value]: 类型值
  /// [name]: 类型名称
  const SearchType({required this.value, required this.name});

  /// 类型值
  final String value;
  /// 类型名称
  final String name;

  /// 根据值获取搜索类型
  /// 
  /// [value]: 类型值
  /// 
  /// 返回值：对应的 SearchType 枚举值
  static SearchType getByValue(String value) {
    return values.firstWhere((element) => element.value == value);
  }
}

/// 音乐源类型枚举
/// 
/// 定义了支持的音乐源：
/// - bili: 哔哩哔哩
/// - youTube: YouTube
enum OriginType {
  bili(value: 'bili', name: '哔哩哔哩'),
  youTube(value: 'youTube', name: 'YouTube');

  /// 构造函数
  /// 
  /// [value]: 类型值
  /// [name]: 类型名称
  const OriginType({required this.value, required this.name});

  /// 类型值
  final String value;
  /// 类型名称
  final String name;

  /// 根据值获取音乐源类型
  /// 
  /// [value]: 类型值
  /// 
  /// 返回值：对应的 OriginType 枚举值
  static OriginType getByValue(String value) {
    return values.firstWhere((element) => element.value == value);
  }
}

/// 搜索参数类
/// 
/// 用于传递搜索相关的参数
class SearchParams {
  /// 搜索关键词
  final String keyword;
  /// 页码
  final int page;

  /// 构造函数
  /// 
  /// [keyword]: 搜索关键词
  /// [page]: 页码
  const SearchParams({
    required this.keyword,
    required this.page,
  });
}

/// 搜索结果抽象类
/// 
/// 定义了搜索结果的通用结构
abstract class SearchResponse {
  /// 当前页码
  final int current;
  /// 总结果数
  final int total;
  /// 每页大小
  final int pageSize;
  /// 搜索结果数据
  final List<SearchItem> data;

  /// 构造函数
  /// 
  /// [current]: 当前页码
  /// [total]: 总结果数
  /// [pageSize]: 每页大小
  /// [data]: 搜索结果数据
  const SearchResponse({
    required this.current,
    required this.total,
    required this.pageSize,
    required this.data,
  });
}

/// 搜索条目类
/// 
/// 表示单个搜索结果项
class SearchItem {
  /// 条目ID
  final String id;
  /// 封面图片URL
  final String cover;
  /// 名称
  final String name;
  /// 时长（秒）
  final int duration;
  /// 作者
  final String author;
  /// 搜索类型
  final SearchType? type;
  /// 音乐源
  final OriginType origin;
  /// 音乐列表（当类型为 order 时会有）
  final List<MusicItem>? musicList;

  /// 构造函数
  /// 
  /// [id]: 条目ID
  /// [cover]: 封面图片URL
  /// [name]: 名称
  /// [duration]: 时长（秒）
  /// [author]: 作者
  /// [origin]: 音乐源
  /// [musicList]: 音乐列表
  /// [type]: 搜索类型
  const SearchItem({
    required this.id,
    required this.cover,
    required this.name,
    required this.duration,
    required this.author,
    required this.origin,
    this.musicList,
    this.type,
  });
}

/// 搜索建议项类
/// 
/// 表示搜索建议的单个条目
class SearchSuggestItem {
  /// 显示内容
  final String name;
  /// 关键词内容
  final String value;

  /// 构造函数
  /// 
  /// [name]: 显示内容
  /// [value]: 关键词内容
  const SearchSuggestItem({
    required this.name,
    required this.value,
  });
}

/// 歌曲简要信息类
/// 
/// 表示歌曲的基本信息
class MusicItem {
  /// 歌曲ID
  final String id;
  /// 封面图片URL
  final String cover;
  /// 歌曲名称
  final String name;
  /// 时长（秒）
  final int duration;
  /// 作者
  final String author;
  /// 音乐源
  final OriginType origin;

  /// 构造函数
  /// 
  /// [id]: 歌曲ID
  /// [cover]: 封面图片URL
  /// [name]: 歌曲名称
  /// [duration]: 时长（秒）
  /// [author]: 作者
  /// [origin]: 音乐源
  const MusicItem({
    required this.id,
    required this.cover,
    required this.name,
    required this.duration,
    required this.author,
    required this.origin,
  });

  /// 从JSON创建MusicItem实例
  /// 
  /// [json]: JSON数据
  /// 
  /// 返回值：MusicItem实例
  factory MusicItem.fromJson(Map<String, dynamic> json) {
    return MusicItem(
      id: json["id"],
      cover: json["cover"],
      name: json["name"],
      duration: json["duration"],
      author: json["author"],
      origin: OriginType.getByValue(json["origin"]),
    );
  }

  /// 转换为JSON
  /// 
  /// 返回值：JSON对象
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "cover": cover,
      "name": name,
      "duration": duration,
      "author": author,
      "origin": origin.value,
    };
  }
}

/// 歌单类
/// 
/// 表示一个歌单及其包含的歌曲
class MusicOrderItem {
  /// 歌单ID
  final String id;
  /// 歌单名称
  final String name;
  /// 歌单描述
  final String desc;
  /// 歌单作者
  final String author;
  /// 歌曲列表
  final List<MusicItem> musicList;
  /// 封面图片URL
  final String? cover;
  /// 创建时间
  final String? createdAt;
  /// 更新时间
  final String? updatedAt;

  /// 构造函数
  /// 
  /// [id]: 歌单ID
  /// [name]: 歌单名称
  /// [desc]: 歌单描述
  /// [author]: 歌单作者
  /// [musicList]: 歌曲列表
  /// [cover]: 封面图片URL
  /// [createdAt]: 创建时间
  /// [updatedAt]: 更新时间
  const MusicOrderItem({
    required this.id,
    required this.name,
    required this.desc,
    required this.author,
    required this.musicList,
    this.cover,
    this.createdAt,
    this.updatedAt,
  });

  /// 从JSON创建MusicOrderItem实例
  /// 
  /// [json]: JSON数据
  /// 
  /// 返回值：MusicOrderItem实例
  factory MusicOrderItem.fromJson(Map<String, dynamic> json) {
    final List<MusicItem> musicList = [];
    for (var item in json["musicList"]) {
      musicList.add(MusicItem.fromJson(item));
    }
    return MusicOrderItem(
      id: json["id"],
      name: json["name"],
      desc: json["desc"],
      author: json["author"] ?? "",
      musicList: musicList,
      cover: json["cover"],
      createdAt: json["createdAt"],
      updatedAt: json["updatedAt"],
    );
  }

  /// 转换为JSON
  /// 
  /// 返回值：JSON对象
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "desc": desc,
      "author": author,
      "musicList": musicList.map((e) => e.toJson()).toList(),
      "cover": cover,
      "createdAt": createdAt,
      "updatedAt": updatedAt,
    };
  }
}

/// 歌曲详情类
/// 
/// 表示歌曲的详细信息，包括播放地址
class MusicDetail {
  /// 歌曲ID
  final String id;
  /// 封面图片URL
  final String cover;
  /// 歌曲名称
  final String name;
  /// 时长（秒）
  final int duration;
  /// 作者
  final String author;
  /// 音乐源
  final OriginType origin;
  /// 播放地址
  final String url;

  /// 构造函数
  /// 
  /// [id]: 歌曲ID
  /// [cover]: 封面图片URL
  /// [name]: 歌曲名称
  /// [duration]: 时长（秒）
  /// [author]: 作者
  /// [origin]: 音乐源
  /// [url]: 播放地址
  const MusicDetail({
    required this.id,
    required this.cover,
    required this.name,
    required this.duration,
    required this.author,
    required this.origin,
    required this.url,
  });
}

/// 音乐URL类
/// 
/// 表示音乐的播放地址和请求头
class MusicUrl {
  /// 播放地址
  final String url;
  /// 请求头
  final Map<String, String>? headers;
  
  /// 构造函数
  /// 
  /// [url]: 播放地址
  /// [headers]: 请求头
  const MusicUrl({required this.url, this.headers});
}

/// 歌单源服务抽象接口
/// 
/// 定义了音乐源服务的基本操作
abstract class OriginService {
  /// 搜索
  /// 
  /// [params]: 搜索参数
  /// 
  /// 返回值：搜索结果
  Future<SearchResponse> search(SearchParams params);

  /// 获取搜索建议
  /// 
  /// [keyword]: 搜索关键词
  /// 
  /// 返回值：搜索建议列表
  Future<List<SearchSuggestItem>> searchSuggest(String keyword);

  /// 获取搜索详情
  /// 
  /// [id]: 条目ID
  /// 
  /// 返回值：搜索条目详情
  Future<SearchItem> searchDetail(String id);

  /// 获取歌曲播放地址
  /// 
  /// [id]: 歌曲ID
  /// 
  /// 返回值：音乐URL对象，包含播放地址和请求头
  Future<MusicUrl> getMusicUrl(String id);

  // /// 下载歌曲
  // Future<void> downloadMusic(String id, String name, String targetDir);
}
