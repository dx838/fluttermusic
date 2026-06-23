class CacheKey {
  /// 歌单广场
  static String openMusicOrderUrls = 'open_music_order_urls';

  /// 歌单广场数据缓存
  static String openMusicOrderDataCache = 'open_music_order_data_cache';

  /// 用户歌单数据缓存前缀
  static String userMusicOrderCachePrefix = 'user_music_order_cache_';

  /// 云歌单配置信息
  static String cloudMusicOrderSetting = 'cloud_music_order_setting';

  /// 本地歌单列表
  static String localMusicOrderList = 'local_music_order_list';

  /// 搜索历史
  static String searchHistory = 'search_history';

  /// 当前播放的歌曲
  static String playerCurrent = 'player_current';

  /// 播放列表
  static String playerList = 'player_list';

  /// 播放历史
  static String playerHistoryList = 'player_history_list';

  /// 播放模式
  static String playerMode = 'player_mode';

  /// 播放进度
  static String playerPosition = 'player_position';

  /// 是否已同步数据库
  static String isSyncDB = 'is_sync_db';

  /// 主题模式（light/dark/system/timed）
  static String themeMode = 'theme_mode';

  /// 定时模式：白天起始时间（时）
  static String themeLightStartHour = 'theme_light_start_hour';

  /// 定时模式：白天起始时间（分）
  static String themeLightStartMinute = 'theme_light_start_minute';

  /// 定时模式：黑夜起始时间（时）
  static String themeDarkStartHour = 'theme_dark_start_hour';

  /// 定时模式：黑夜起始时间（分）
  static String themeDarkStartMinute = 'theme_dark_start_minute';
}
