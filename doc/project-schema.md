# 哔哔音乐（bbmusic）项目编码方案

> 版本：v1.6.0 · 适用 SDK：Flutter >=3.27.1 / Dart >=3.3.1 <4.0.0
> 适用平台：Android / iOS / macOS / Windows / Linux

---

## 1. 项目概况

### 1.1 项目定位

- 名称：**bbmusic**（哔哔音乐，听歌自由）
- 简介：以 B 站视频音频流作为曲源的个人音乐播放器
- 主要功能：搜索、播放（播放列表/模式控制/进度/定时关闭）、本地/云端歌单、歌单广场（GitHub/Gitee/WebDAV/本地分享）
- 平台范围：移动端 + 桌面端

### 1.2 技术栈

| 类别 | 库/框架 | 用途 |
| --- | --- | --- |
| 框架 | Flutter | 跨端 UI |
| 状态管理 | `provider` | ChangeNotifier 模式 |
| 音频播放 | `just_audio` + `just_audio_media_kit` | Windows/Linux 使用 media_kit 后端 |
| 后台播放 | `audio_service` | 通知、媒体控制、锁屏控制 |
| 数据库 | `drift` + `drift_flutter` | 本地 SQLite（drift_database） |
| KV 存储 | `shared_preferences` | 配置/当前歌曲/播放进度/播放列表备份 |
| 网络 | `dio`、`http` | API 请求 + 流式下载 |
| 文件缓存 | `flutter_cache_manager` | 音频缓存（CacheManager `bbmusicMediaCache`） |
| 图片 | `cached_network_image` | 封面/歌单封面 |
| 工具 | `bot_toast`、`logger`、`uuid`、`path_provider`、`permission_handler`、`file_picker`、`window_manager`、`url_launcher`、`package_info_plus` | 提示/日志/ID/路径/权限/选择文件/窗口/外链/版本 |

### 1.3 目录结构（核心）

```
lib/
├── main.dart                    # 入口、Provider 注入、AudioService.init、生命周期管理
├── constants/cache_key.dart     # SharedPreferences key
├── database/                    # Drift 数据库（PlayerListEntity 等）
│   ├── database.dart            # AppDatabase 单例（修复 M10）
│   ├── database.g.dart
│   └── entity/...
├── icons/                       # 图标
├── origin_sdk/                  # B 站 API 适配（bili / 服务编排）
├── modules/
│   ├── home/                    # 首页
│   ├── player/                  # 播放器
│   │   ├── instance.dart        # BBPlayer 核心逻辑（修复 M1/M2/M4/M8/M9/M13/P1-P3）
│   │   ├── model.dart           # PlayerModel（ChangeNotifier，修复 M2）
│   │   ├── service.dart         # AudioPlayerHandler（BaseAudioHandler，修复 M3）
│   │   ├── source.dart          # BBMusicSource（StreamAudioSource + 缓存，修复 M4/M5/M6/M7）
│   │   ├── card.dart            # 播放卡片
│   │   ├── list.dart            # 播放列表
│   │   ├── player.dart          # 迷你播放条
│   │   └── const.dart           # PlayerMode / PlayerStatus
│   ├── download/                # 下载
│   ├── search/                  # 搜索
│   ├── music_order/             # 我的歌单
│   ├── open_music_order/        # 歌单广场
│   ├── user_music_order/        # 用户歌单源（github/gitee/webdav/local）
│   ├── data_sync/               # 老数据 → DB 一次性同步
│   └── setting/                 # 设置 + 本地数据导入导出
├── components/                  # 通用组件
└── utils/                       # 工具（Throttle、HTML tag 清理、窗口管理、版本更新、Logs）
```

### 1.4 核心数据流

```
UI (Consumer<PlayerModel>)
  └── PlayerModel (ChangeNotifier)
        └── AudioPlayerHandler (BaseAudioHandler)
              └── BBPlayer
                    ├── AudioPlayer (just_audio)
                    │     └── BBMusicSource (StreamAudioSource)
                    │           ├── http.Client（流式下载到临时文件）
                    │           └── audioCacheManage（CacheManager 带 LRU 上限）
                    ├── SharedPreferences (current / mode / history / position / playerList)
                    └── AppDatabase (drift 单例)  ←  PlayerListEntity 持久化备份
```

---

## 2. 已修复的问题（全部完成）

### 2.1 内存持续增长（**Issue #28**） ✅

经过对 `lib/modules/player/` 模块的逐文件审计与修复，已解决所有内存泄漏问题。

| # | 位置 | 问题 | 修复方案 | 状态 |
| --- | --- | --- | --- | --- |
| M1 | `player/instance.dart` | `audio.playerStateStream.listen` 与 `audio.positionStream.listen` 监听未保存 `StreamSubscription`，`dispose()` 中未 `cancel()` | 增加 `_subs: List<StreamSubscription<dynamic>>`，所有 listen 加入该列表，dispose 中统一 cancel | ✅ |
| M2 | `player/model.dart` | `PlayerModel.init()` 每次都会新加 `playerStateStream.listen`，没有 cancel 旧的 | 增加 `_stateSub: StreamSubscription?`，init 前先 cancel 旧订阅，dispose 中 cancel | ✅ |
| M3 | `player/service.dart` | `playbackEventStream` / `playerStateStream` / `positionStream` / `durationStream` 4 个 listen 未保存 `StreamSubscription` 也未 cancel | 增加 `_subs: List<StreamSubscription<dynamic>>`，所有 listen 加入该列表，dispose 中统一 cancel | ✅ |
| M4 | `player/source.dart` | `BBMusicSource._bytes: List<int>` 将整首歌字节装入内存；切歌未释放旧 source | 去掉 `_bytes` 字段，改为下载到临时文件后用 `file.openRead()` 透传；`_play()` 中增加 `audio.clearAudioSources()` | ✅ |
| M5 | `player/source.dart` | 每次创建新的 `http.Client()`，没有调用 `client.close()` | `BBMusicSource` 持有 `Client? _httpClient`，在 `dispose()` 中统一关闭 | ✅ |
| M6 | `player/source.dart` | `onDone` 回调里 `Uint8List.fromList(_bytes)` 再 `putFile` 写盘，写完后 `_bytes` 未清理 | 去掉 `_bytes` 字段，直接流式写入临时文件，不再保留字节数组 | ✅ |
| M7 | `player/source.dart` | `audioCacheManage` 用 `maxAge: 100 年`，无 LRU 上限 | 改为 `stalePeriod: Duration(days: 30)`，`maxNrOfCacheObjects: 200` | ✅ |
| M8 | `player/instance.dart` | `playerStateStream` 内部用 `Throttle(1s)` 创建新 Timer，throttle 实例为局部变量 | `Throttle` 实例改为 `init()` 局部变量，流订阅由 `_subs` 统一管理，dispose 时释放 | ✅ |
| M9 | `player/instance.dart` | `positionStream.listen` 闭包内 `t` 变量被闭包捕获，无清理入口 | 流订阅加入 `_subs`，dispose 时统一 cancel，释放闭包引用 | ✅ |
| M10 | `database/database.dart` | `AppDatabase()` 每次 `new` 一个实例，多入口持有不同连接 | 改为单例模式：`factory AppDatabase() => _instance ??= AppDatabase._(_openConnection())` | ✅ |
| M11 | 整体 | 没有 `WidgetsBindingObserver` / `didChangeAppLifecycleState` | `main.dart` 中已注册 `_AppLifecycleObserver`，`paused` 时释放非必要资源 | ✅ |
| M12 | 全局 | `CachedNetworkImage` 全部用默认缓存，未主动清理 | `paused` 时调用 `PaintingBinding.instance.imageCache.clear()` | ✅ |
| M13 | `player/instance.dart` | `BBPlayer.dispose()` 只 `audio.dispose()` 和 `_timer?.cancel()` | 增加 `_subs` cancel、`_playerHistory.clear()` 等完整清理 | ✅ |

> 修复后，流订阅统一管理、切歌释放旧 source、HTTP Client 及时关闭、图片缓存可控，内存增长问题已解决。

### 2.2 关闭后再打开播放列表为空 ✅

| # | 位置 | 问题 | 修复方案 | 状态 |
| --- | --- | --- | --- | --- |
| P1 | `instance.dart` | `_initLocalStorage()` 先调用 `_play()` 再恢复 `playerList` | 调整顺序：先 `_restorePlayerListFromLocalStorage()` 再 `_play()` | ✅ |
| P2 | `instance.dart` | `play()` 中 `addPlayerList([music])` 无 `await`，竞态导致数据丢失 | `addPlayerList` 改为同步方法，不再立即写库；资源消耗极低 | ✅ |
| P3 | `instance.dart` | `_updateLocalStorage()` 仅保存 current/mode/history，不保存 `playerList` | 增加 `playerList` 序列化到 SharedPreferences，`_updateLocalStorage()` 中同步保存 | ✅ |
| P4 | `instance.dart` | `_updateLocalStorage()` 防抖延迟单位错误：`microseconds: 3000` = 3 毫秒 | 改为 `milliseconds: 3000` = 3 秒 | ✅ |
| P5 | `database/database.dart` | `AppDatabase()` 每次 `new` 一个实例 | 单例化：所有访问走同一连接 | ✅ |
| P6 | `instance.dart` | 没有显式 close 入口 | 由 `AppLifecycleState.detached` 时调用 `syncCache()` 释放 | ✅ |

> 修复后，采用 **"内存缓存 + 关键时机批量写入"** 策略：
> - 日常操作（添加/移除歌曲）仅更新内存，不立即写库
> - `_updateLocalStorage()` 防抖 3 秒后将 `playerList` 备份到 SharedPreferences
> - `syncCache()` 在退出/后台时批量写入数据库
> - 启动恢复：优先 SharedPreferences（内存级读取）→ 降级数据库 → 兜底（current 加入列表）

---

## 3. 已实施的修复方案

### 3.1 总原则（已实现）

1. ✅ **以 PlayerModel 为唯一入口**：所有对播放器的操作经 `PlayerModel`，由其统一管理 `AudioPlayerHandler` 与底层流订阅生命周期。
2. ✅ **所有 `Stream.listen` 必须保存 `StreamSubscription` 并在 `dispose()` 中 `cancel`**。
3. ✅ **资源按"组件级 + 应用级"两层释放**：
   - 组件级：`StatefulWidget.dispose`（`PlayerProgress` 等已有取消 listen 逻辑）
   - 应用级：`WidgetsBindingObserver.didChangeAppLifecycleState` 在 `paused/detached` 时降级
4. ✅ **Drift 数据库单例化**，并由 `AppLifecycleState.detached` 时关闭。
5. ✅ **BBMusicSource 不缓存整首到内存**：流式下载到临时文件后用 `file.openRead()` 透传，不再保留 `_bytes`。
6. ✅ **playerList 持久化**：SharedPreferences 轻量级备份 + 退出时数据库批量写入。

### 3.2 内存问题修复方案（已完成）

#### 3.2.1 流订阅统一管理 ✅

**目标**：消除 M1/M2/M3/M8/M9/M13。

**已改动文件**：
- `lib/modules/player/instance.dart`
- `lib/modules/player/model.dart`
- `lib/modules/player/service.dart`

**实际实现**：

1. `BBPlayer` 中维护 `_subs: List<StreamSubscription<dynamic>>`：
   ```dart
   final List<StreamSubscription<dynamic>> _subs = [];
   // 所有 listen 改为
   _subs.add(audio.playerStateStream.listen(...));
   _subs.add(audio.positionStream.listen(...));
   ```
   `dispose()` 中：
   ```dart
   for (final s in _subs) { await s.cancel(); }
   _subs.clear();
   _playerHistory.clear();
   ```

2. `PlayerModel` 持有 `StreamSubscription? _stateSub`：
   - `init()` 中先 `await _stateSub?.cancel();` 再 `listen`
   - `dispose()` 中 `cancel()`

3. `AudioPlayerHandler` 同样维护 `_subs: List<StreamSubscription<dynamic>>`，`dispose()` 中释放。

#### 3.2.2 切歌前释放旧 source / Client ✅

**目标**：消除 M4/M5/M6。

**已改动文件**：`lib/modules/player/source.dart`、`lib/modules/player/instance.dart`

**实际实现**：

1. **`BBMusicSource` 重构**：
   - 去掉 `_bytes: List<int>` 字段
   - `_download()` 流式下载到临时文件（`path_provider.getTemporaryDirectory()`）
   - `request(start, end)` 返回 `file.openRead(start, end).asBroadcastStream()`
   - 持有 `Client? _httpClient` 和 `StreamSubscription? _responseSub`，在 `dispose()` 中关闭和取消
   - `dispose()` 中删除临时文件

2. **`BBPlayer._play()`**：
   ```dart
   await audio.stop();
   await audio.clearAudioSources();   // 关键：释放旧的 StreamAudioSource
   await audio.setAudioSources([BBMusicSource(music)]);
   ```

3. **`audioCacheManage` 加 LRU 上限**：
   ```dart
   CacheManager(Config(
     "bbmusicMediaCache",
     stalePeriod: Duration(days: 30),
     maxNrOfCacheObjects: 200,
   ))
   ```

#### 3.2.3 图片缓存释放 ✅

**目标**：消除 M12。

**已改动文件**：`lib/main.dart`

**实际实现**：

在 `main.dart` 的 `_AppLifecycleObserver` 中，`paused` 状态时：
```dart
void _onAppBackground() {
  PaintingBinding.instance.imageCache.clear();
}
```

#### 3.2.4 应用生命周期 + 资源降级 ✅

**目标**：消除 M11。

**已改动文件**：`lib/main.dart`

**实际实现**：

```dart
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      await _playerHandler.player.syncCache();
      _onAppBackground();
    } else if (state == AppLifecycleState.detached) {
      await _onAppExit();
    }
  }
}
```

#### 3.2.5 AppDatabase 单例化 ✅

**目标**：消除 M10。

**已改动文件**：`lib/database/database.dart`

**实际实现**：

```dart
class AppDatabase extends _$AppDatabase {
  AppDatabase._(QueryExecutor e) : super(e);
  static AppDatabase? _instance;
  factory AppDatabase() => _instance ??= AppDatabase._(_openConnection());
  factory AppDatabase.withExecutor(QueryExecutor e) =>
      _instance ??= AppDatabase._(e);
  @override
  int get schemaVersion => 1;
}
```

### 3.3 播放列表持久化（已完成）

**目标**：保证任何时候关闭/崩溃，下次打开仍能恢复完整播放列表与当前曲目。

**已改动文件**：`lib/modules/player/instance.dart`

#### 3.3.1 写库策略优化 ✅

- `addPlayerList()` / `removePlayerList()` / `clearPlayerList()` 改为**同步方法**，仅更新内存
- 消除每次操作都写库的竞态问题和资源消耗

#### 3.3.2 启动时加载 playerList ✅

`_initLocalStorage()` 调整顺序：
1. 读取 `current` / `playerMode` / `_playerHistory`
2. **先调用 `_restorePlayerListFromLocalStorage()`**
3. 再调用 `_play(music: current!, isPlay: false)`

恢复优先级：
1. SharedPreferences（内存级，最快）
2. 降级到数据库
3. 兜底：如果列表为空但有 current，把 current 加入列表

#### 3.3.3 双写机制 ✅

`_updateLocalStorage()`（防抖 3 秒）：
- 保存 `current` / `playerMode` / `_playerHistory`
- **新增**：保存 `playerList` 到 SharedPreferences（轻量级序列化）

`syncCache()`（退出/后台时）：
- 保存上述所有数据
- **批量写入数据库**：`_persistPlayerListToDb()` 一次性 replace

#### 3.3.4 防抖单位修复 ✅

`_updateLocalStorage()` 中 `Timer` 的延迟单位从 `microseconds: 3000`（3 毫秒）修复为 `milliseconds: 3000`（3 秒）。

---

## 4. 验证结果

| 任务 | 验证方法 | 状态 |
| --- | --- | --- |
| 内存不增长 | 连续播放 50 首歌，DevTools Memory 面板确认无持续增长 | ✅ 通过 |
| 流订阅无泄漏 | 反复切歌，`StreamSubscription` 总数保持恒定 | ✅ 通过 |
| 播放列表持久化 | 搜索一首歌 → 播放 → 退出 → 重启 → 恢复列表与当前曲目 | ✅ 通过 |
| 图片缓存受控 | 进入后台再返回，imageCache 数量下降 | ✅ 通过 |
| Windows 编译 | GitHub Actions 使用 `windows-2022` 镜像编译通过 | ✅ 通过 |

---

## 5. 实施顺序（已完成）

1. ✅ **先行准备**：建立 `AppDatabase` 单例、注册 `WidgetsBindingObserver`
2. ✅ **修复流订阅泄漏**（3.2.1）：最小改动、独立可验证
3. ✅ **重构 BBMusicSource 去掉 `_bytes`**（3.2.2）：核心内存点
4. ✅ **修复播放列表持久化**（3.3.1 → 3.3.4）
5. ✅ **图片缓存 + 后台降级**（3.2.3 / 3.2.4）
6. ✅ **DevTools 内存 profiling 验证**
7. ✅ **Windows 编译修复**：C++20 标准、CMake 策略、Visual Studio 版本锁定

---

## 6. 范围外（明确不做）

- 不重构播放器状态管理为 Riverpod/Bloc（与任务无关）
- 不修改 just_audio_media_kit / media_kit 后端选型
- 不动歌单广场/云端同步逻辑
- 不删除 `print` 之外的注释代码（仅清理本次新引入或与内存问题直接相关的死代码）

---

## 7. 主题系统改进方案（已实施）

### 7.1 背景与目标

原项目使用单一浅色主题（`ThemeData` 写死在 `main.dart`），无法满足夜间使用场景。
本次新增主题配置模块，支持：

1. **手动切换**：浅色（白天）/深色（黑夜）二选一
2. **跟随系统**：根据系统 `platformBrightness` 动态切换
3. **定时切换**：用户指定"白天开始时间"和"黑夜开始时间"，到达时间点自动切换

深色模式约定：**背景纯白 → 纯黑 (`Colors.black`)，字体统一改为白色**（`Colors.white` / `Colors.white70`）。

### 7.2 新增文件

| 文件 | 说明 |
| --- | --- |
| `lib/theme/themes.dart` | 定义 `buildLightTheme()` 与 `buildDarkTheme()` 两套 `ThemeData`，深色模式将 `scaffoldBackgroundColor`/`canvasColor`/`cardColor` 全部置为 `Colors.black`，`textTheme` 全部字体置为白色 |
| `lib/theme/theme_model.dart` | `ThemeModel extends ChangeNotifier with WidgetsBindingObserver`，管理当前模式、定时计算、`Timer` 调度和系统亮度变化监听 |

### 7.3 改动文件

| 文件 | 改动 |
| --- | --- |
| `lib/constants/cache_key.dart` | 新增 5 个主题持久化键：`themeMode`、`themeLightStartHour/Minute`、`themeDarkStartHour/Minute` |
| `lib/main.dart` | 移除顶层固定 `theme`，改用 `MultiProvider` 注入 `ThemeModel`；根组件 `_AppRoot` 使用 `Consumer<ThemeModel>` 根据 `brightness` 动态选择 `buildLightTheme()` / `buildDarkTheme()`；启动时异步 `init()` 读取本地设置 |
| `lib/modules/setting/setting.dart` | 新增 `_ThemeSettingTile` 入口 + `_ThemeDialog` 弹窗，支持四个单选项（浅色/深色/跟随系统/定时切换），选择定时模式时弹出两个 `TimePicker` 配置切换时间 |
| `lib/modules/home/home.dart` | 将 `Colors.black38` 改为 `Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)`，避免深色下对比度问题 |

### 7.4 核心实现要点

1. **模式枚举**
   ```dart
   enum ThemeMode { light, dark, system, timed }
   ```

2. **定时亮度计算**（`_computeTimedBrightness`）
   - 同日情形：`[lightStart, darkStart)` 为白天，其余为黑夜
   - 跨天情形（黑夜时间早于白天）：`[lightStart, 24:00) + [0:00, darkStart)` 为白天
   - `lightStart == darkStart` 时兜底为白天

3. **定时调度**（`_scheduleTimerIfNeeded`）
   - 根据当前时间计算下一次切换点（可能在今天或明天）
   - 使用单次 `Timer` 触发后递归重排，保证长期运行下的切换准确性
   - 调用 `setMode` / `setLightStart` / `setDarkStart` 时自动重排

4. **系统跟随**
   - `ThemeModel` 作为 `WidgetsBindingObserver` 监听 `didChangePlatformBrightness`
   - 仅当模式为 `system` 时响应

5. **持久化**
   - 全部通过 `SharedPreferences` 保存（与项目其他配置一致）

### 7.5 后续可改进（未实施，列入待办）

- 将 `lib/modules/home/home.dart`、`lib/modules/open_music_order/list_view.dart`、`lib/modules/setting/setting.dart` 中散落的 `Colors.black/white/black87/...` 统一替换为 `Theme.of(context).colorScheme` 语义色，彻底杜绝硬编码颜色
- 为播放器卡片 `lib/modules/player/card.dart` / `list.dart` 单独设置深色语义色（背景/分割线）
- 深色模式下封面蒙层 `Color.fromRGBO(0,0,0,0.4)` 已兼容，可视需要调整为 `Colors.black54`
- 增加"当前模式"预览气泡（设置页弹出对话框时展示实际切换效果）

---

## 8. 其他可改进建议（供后续迭代参考）

### 8.1 代码组织

1. **主题常量去重**：`primaryColor` 原先在 `main.dart` 顶层，现迁移到 `themes.dart`，建议后续把所有视觉常量集中到 `lib/theme/` 下，避免散落
2. **设置页状态化**：`SettingView` 目前是 `StatelessWidget`，与主题弹窗交互时依赖 `ThemeModel`，建议后续把非持久化字段（如"清理缓存"进度）下沉到 `SettingModel`
3. **播放器视图主题对齐**：`player.dart` 中 `secondaryHeaderColor` 可在 `ThemeData` 中显式定义，避免依赖默认色
4. **国际化**：当前所有文案为中文硬编码，如需海外发布建议引入 `easy_localization` 等
5. **错误监控**：加入 `logger` + `Crashlytics`（或 Sentry）统一上报

### 8.2 性能与体验

1. **启动流程**：`main.dart` 中 `autoSyncLocalDataToDatabase()`、`AudioService.init()`、`ThemeModel.init()` 为串行，可评估改为并行加速冷启动
2. **图片缓存策略**：`CachedNetworkImage` 未区分深浅色缓存路径，深色模式下若后续加入深色封面需规划
3. **列表滚动性能**：`SearchView`、`MusicOrderListView` 长列表中 `ListView` 可改为 `SliverList.builder` 按需构建

### 8.3 功能增强

1. **定时关闭**：播放器已有 `autoClose` 基础，可在设置页提供显式入口
2. **播放统计**：基于 `playerHistoryList` 增加最近 7 天播放时长/曲目数统计
3. **歌词支持**：接入 B 站评论区或第三方歌词源
4. **桌面端系统托盘**：配合 `window_manager` 增加最小化到托盘 + 托盘菜单切换主题/播放控制

### 8.4 已完成的文档索引调整

- 新增第 7 章"主题系统改进方案"
- 新增第 8 章"其他可改进建议"
- 原有第 7 章"关键文件索引"顺延至第 9 章

---

## 9. 关键文件索引

| 关注点 | 文件 | 修复内容 |
| --- | --- | --- |
| 播放器核心逻辑 | [instance.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/modules/player/instance.dart) | M1/M4/M8/M9/M13/P1-P6 |
| 播放器状态层 | [model.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/modules/player/model.dart) | M2 |
| AudioService 集成 | [service.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/modules/player/service.dart) | M3 |
| 音频源 + 缓存 | [source.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/modules/player/source.dart) | M4/M5/M6/M7 |
| 入口与 Provider | [main.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/main.dart) | M11/M12 |
| 数据库 | [database.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/database/database.dart) | M10 |
| 播放列表实体 | [player_list.entity.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/database/entity/player_list.entity.dart) | - |
| 老数据迁移 | [data_sync.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/modules/data_sync/data_sync.dart) | - |
| 缓存键 | [cache_key.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/constants/cache_key.dart) | - |
| 节流工具 | [utils.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/utils/utils.dart) | - |
| Windows 构建 | [windows/CMakeLists.txt](file:///d:/Program/WebProjects/bilimusic/fluttermusic/windows/CMakeLists.txt) | C++20 + 编译选项 |
| CI 配置 | [.github/workflows/release-windows.yaml](file:///d:/Program/WebProjects/bilimusic/fluttermusic/.github/workflows/release-windows.yaml) | windows-2022 |
