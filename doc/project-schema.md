# 哔哔音乐（bbmusic）项目编码方案

> 版本：v1.5.1+12 · 适用 SDK：Flutter >=3.27.1 / Dart >=3.3.1 <4.0.0
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
| KV 存储 | `shared_preferences` | 配置/当前歌曲/播放进度 |
| 网络 | `dio`、`http` | API 请求 + 流式下载 |
| 文件缓存 | `flutter_cache_manager` | 音频缓存（CacheManager `bbmusicMediaCache`） |
| 图片 | `cached_network_image` | 封面/歌单封面 |
| 工具 | `bot_toast`、`logger`、`uuid`、`path_provider`、`permission_handler`、`file_picker`、`window_manager`、`url_launcher`、`package_info_plus` | 提示/日志/ID/路径/权限/选择文件/窗口/外链/版本 |

### 1.3 目录结构（核心）

```
lib/
├── main.dart                    # 入口、Provider 注入、AudioService.init
├── constants/cache_key.dart     # SharedPreferences key
├── database/                    # Drift 数据库（PlayerListEntity 等）
│   ├── database.dart
│   ├── database.g.dart
│   └── entity/...
├── icons/                       # 图标
├── origin_sdk/                  # B 站 API 适配（bili / 服务编排）
├── modules/
│   ├── home/                    # 首页
│   ├── player/                  # 播放器
│   │   ├── instance.dart        # BBPlayer 核心逻辑（list/模式/缓存/历史）
│   │   ├── model.dart           # PlayerModel（ChangeNotifier）
│   │   ├── service.dart         # AudioPlayerHandler（BaseAudioHandler）
│   │   ├── source.dart          # BBMusicSource（StreamAudioSource + 缓存）
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
                    │           ├── http.Client (流式拉音频)
                    │           └── audioCacheManage (CacheManager 写盘)
                    ├── SharedPreferences (current / mode / history / position)
                    └── AppDatabase (drift)  ←  PlayerListEntity 播放列表
```

---

## 2. 当前已识别的问题

### 2.1 内存持续增长（**Issue #28**）

经过对 `lib/modules/player/` 模块的逐文件审计，确认存在多处资源未释放/未取消订阅，长期运行会逐步累积。

| # | 位置 | 问题 | 影响 |
| --- | --- | --- | --- |
| M1 | `player/instance.dart` L87/116 | `audio.playerStateStream.listen` 与 `audio.positionStream.listen` 监听没有保存 `StreamSubscription`，`dispose()` 中没有 `cancel()` | 每次重建不会释放，闭包内捕获的对象常驻 |
| M2 | `player/model.dart` L70 | `PlayerModel.init()` 每次都会新加 `playerStateStream.listen`，没有 `cancel` 旧的；`main.dart` 的 `builder` 多次构建时会被反复调用 | 通知链路重复，旧引用持有无法回收 |
| M3 | `player/service.dart` L41/46/62/67 | `playbackEventStream` / `playerStateStream` / `positionStream` / `durationStream` 4 个 listen 都未保存 `StreamSubscription` 也未 cancel | 同 M1，并触发多次 `_updateMediaItem`/`_broadcastState` |
| M4 | `player/source.dart` L29 + L470 | `BBMusicSource._bytes: List<int>` 在每首歌完整缓冲期间将整首歌字节装入内存；`audio.setAudioSources([new])` 切换时没有先 `audio.clearAudioSources()`，旧 source 是否被释放取决于底层实现 | 单曲可占用数 MB～数十 MB 内存 |
| M5 | `player/source.dart` L69 | 每次创建新的 `http.Client()`，没有调用 `client.close()`，底层连接池不会被释放 | 连接句柄+缓冲区泄漏 |
| M6 | `player/source.dart` L84-92 | `onDone` 回调里 `Uint8List.fromList(_bytes)` 再 `putFile` 写盘，写完后 `_bytes` 没有 `.clear()` | 写盘后旧字节仍驻留直到 GC |
| M7 | `player/source.dart` L22 + L91 | `audioCacheManage` 用 `maxAge: 100 年`，**无 LRU 上限、无主动清理** | 磁盘与内存缓存只增不减 |
| M8 | `player/instance.dart` L88-110 | `playerStateStream` 内部还用 `Throttle(1s)` 创建新 Timer，但 throttle 实例只作为局部变量在 init 期间存在；每次 `init` 调用都会产生新 Timer 链 | 旧 Timer 与上下文泄漏 |
| M9 | `player/instance.dart` L116-122 | `positionStream.listen` 闭包内 `t` 变量被闭包捕获并被反复 `add`，无清理入口 | 闭包对象常驻 |
| M10 | `modules/*` 多处 | `AppDatabase()` 作为 `final db = AppDatabase();` 字段被多次实例化（如 `data_sync.dart`、`open_music_order/*`、`local_data.dart`、`music_order_origin/mode.dart` 等 9 处） | drift 连接句柄未关闭会保留 native 资源 |
| M11 | 整体 | **没有 `WidgetsBindingObserver` / `didChangeAppLifecycleState`** | 应用进入后台/隐藏时不释放/降级任何资源 |
| M12 | `card.dart`/UI | `CachedNetworkImage` 全部用默认缓存，**没有调用 `PaintingBinding.instance.imageCache.clear()` / `evict`** | 封面图片占用持续增长 |
| M13 | `instance.dart` L125-131 | `BBPlayer.dispose()` 只 `audio.dispose()` 和 `_timer?.cancel()`，未释放 `db`、未取消 `instance` 内部 listen、未释放 `_playerHistory` | 显式销毁路径也不彻底 |

> 总结：核心问题在 M1–M6：流订阅没有保存与取消、`BBMusicSource._bytes` 整首歌曲驻留、HTTP `Client` 未关闭。这三者叠加后，**每播一首歌就净增一份内存**，长时间播放必然 OOM。

### 2.2 关闭后再打开播放列表为空

| # | 位置 | 现象/根因 |
| --- | --- | --- |
| P1 | `instance.dart` L74-123 / L516-557 | `init()` → `_initLocalStorage()`：从 `SharedPreferences` 只恢复 `current` / `playerMode` / `_playerHistory` / `playerPosition`；**没有从 `PlayerListEntity` 读取并填入 `playerList`**（仅在末尾调用了 `reloadPlayerList()`）。如果 `isSyncDB=true` 且 `playerListEntity` 为空（首次冷启动前没有经过"播放一首歌 → addPlayerList 写入 DB"），`playerList` 就为空 |
| P2 | `instance.dart` L155-157 | `addPlayerList` 是 `Future` 但 `play()` 用 `addPlayerList([music])`（无 `await`），竞态：写入 DB 之前若进程退出/被杀，会丢歌 |
| P3 | `instance.dart` L491-513 | `_updateLocalStorage()` 仅保存 `current` / `playerMode` / `_playerHistory`，**不保存 `playerList`**。`playerList` 完全依赖 DB 持久化 |
| P4 | `data_sync.dart` L15-77 | 老数据一次性同步只在新装首次启动执行；只要用户没走过 `addPlayerList` 路径（仅靠"打开歌单→播放"流程可能走，也可能因 P2 的竞态未落库），DB 就可能为空 |
| P5 | `database.dart` L34 | `AppDatabase()` 每次 `new` 一个实例，没有提供应用单例；多入口持有不同连接，存在数据库文件锁风险（drift 内部会处理，但增加 native 句柄） |
| P6 | `instance.dart` L71 | `final db = AppDatabase();` 在 `BBPlayer` 字段初始化时立即 new，且没有 close 入口 | 与 M10 共同加重 |

> 结论：**`playerList` 持久化依赖 Drift 的 `PlayerListEntity`，而代码路径上写库是 `addPlayerList` 异步操作 + `_play` 切歌竞态**。在用户每次只点一首歌播放时，多半能落库；但在"导入歌单 → 立即退出/被杀/崩溃"等场景会丢。

### 2.3 其他（次要）

- 注释/日志散乱，存在 `print`、`Fluttertoast` 注释残留、`// import 'package:bbmusic/utils/logs.dart';` 等死代码
- `BBPlayer.audio.bufferedPositionStream` 注释掉的 debug 仍存在
- `infinite_rotate/comp.dart` 动画控制器 dispose 正常，但播放器卡片/列表关闭时未通知后台清理
- 桌面端 `JustAudioMediaKit.ensureInitialized` 仅启用 Windows/Linux，macOS 为 `false`（与 README 描述的 macOS 打包存在差异，但不在本次任务范围）

---

## 3. 编码方案

### 3.1 总原则

1. **以 PlayerModel 为唯一入口**：所有对播放器的操作经 `PlayerModel`，由其统一管理 `AudioPlayerHandler` 与底层流订阅生命周期。
2. **所有 `Stream.listen` 必须保存 `StreamSubscription` 并在 `dispose()` 中 `cancel`**。
3. **资源按"组件级 + 应用级"两层释放**：
   - 组件级：`StatefulWidget.dispose`（`PlayerCard`、`PlayerList`、`DownloadListView` 等已有或补齐）
   - 应用级：`WidgetsBindingObserver.didChangeAppLifecycleState` 在 `paused/detached/hidden` 时降级
4. **Drift 数据库单例化**，并由 `AppLifecycleState.detached` 时关闭。
5. **BBMusicSource 改为不缓存整首到内存**：完全用 `file.openRead()` 透传缓存文件流；未命中缓存时用临时文件落盘后再 stream，**不再保留 `_bytes`**。
6. **playerList 持久化** 改为：写库完成后再切换音频源；`init` 阶段把 `playerList` 真正加载到内存。

### 3.2 内存问题修复方案（任务 1）

#### 3.2.1 流订阅统一管理

**目标**：消除 M1/M2/M3/M8/M9/M13。

**改动文件**：
- `lib/modules/player/instance.dart`
- `lib/modules/player/model.dart`
- `lib/modules/player/service.dart`

**步骤**：

1. 在 `BBPlayer` 中维护 `_subs: List<StreamSubscription>`：
   ```dart
   final List<StreamSubscription> _subs = [];
   // 替换 audio.playerStateStream.listen(...) 为
   _subs.add(audio.playerStateStream.listen(...));
   ```
   并在 `dispose()` 中 `for (final s in _subs) { s.cancel(); }`、清空 `_subs`、清空 `_playerHistory`。

2. `PlayerModel` 改为持有 `StreamSubscription? _stateSub`：
   - `init()` 中先 `await _stateSub?.cancel();` 再 `listen`，保证只一个订阅
   - 在 `PlayerModel.dispose()`（Provider 释放时调用，见 3.2.4）中 cancel

3. `AudioPlayerHandler`（`service.dart`）同样维护 `_subs: List<StreamSubscription>`，并在 `dispose()` 释放；`BaseAudioHandler` 自带 `dispose()` 需 override。

#### 3.2.2 切歌前释放旧 source / Client

**目标**：消除 M4/M5/M6。

**改动文件**：`lib/modules/player/source.dart`、`lib/modules/player/instance.dart`

1. **`BBMusicSource` 重构**（关键）：
   - 去掉 `_bytes: List<int>` 字段
   - `_init()` 改为：检查缓存命中 → 命中则 `sourceLength` 取自文件长度；未命中则用 dio/http 将流式下载写到临时文件（`path_provider.getTemporaryDirectory()`），完成后用 `file.openRead()` 透传
   - `request(start, end)` 改为：缓存命中或临时文件就绪后，返回 `file.openRead(start, end).asBroadcastStream()`
   - `onDone` 内不再保留 `Uint8List`
   - 取消/切歌时 `BBMusicSource.dispose()` 中删除临时文件（用 `dart:io` 句柄持有）

2. **`BBPlayer._play()`**：
   ```dart
   await audio.stop();
   await audio.clearAudioSources();   // 关键：释放旧的 StreamAudioSource
   await audio.setAudioSources([BBMusicSource(music)]);
   await audio.play();
   ```

3. **`BBMusicSource` 持有 `http.Client` / dio 实例**：
   - 用 `try { ... } finally { client?.close(); }` 兜底关闭
   - 推荐用 `package:dio` + `CancelToken`，切歌时 `cancelToken.cancel("switch")`

4. **`audioCacheManage`** 加 LRU 上限：
   - 创建时指定 `Config("bbmusicMediaCache", stalePeriod: ..., maxNrOfCacheObjects: 200, fileService: ...)`
   - 或在 `BBPlayer` 启动时 `await audioCacheManage.emptyCache()` 一次作为冷启动清理

#### 3.2.3 图片缓存与无图列表的释放

**目标**：消除 M12。

**改动文件**：`lib/modules/player/card.dart`、`lib/components/music_list_tile/music_list_tile.dart` 等用 `CachedNetworkImage` 处。

- 在 `PlayerCard` 等组件 `dispose()` 中按需：
  ```dart
  @override
  void dispose() {
    // 取消已订阅的 listen（已有）
    // 主动 evict 当前封面
    if (player.current?.cover.isNotEmpty == true) {
      DefaultCacheManager().removeFile(player.current!.cover);
    }
    super.dispose();
  }
  ```
- 应用进入后台时（见 3.2.4）调用 `PaintingBinding.instance.imageCache.clear()` + `imageCache.evict(memoryImageLimit 触发)`。

#### 3.2.4 应用生命周期 + 资源降级

**目标**：消除 M11。

**改动文件**：新增 `lib/utils/app_lifecycle.dart`、改 `lib/main.dart`、`lib/modules/player/model.dart`。

1. 在 `main.dart` 注册 `WidgetsBindingObserver`：
   ```dart
   class _AppLifecycleObserver with WidgetsBindingObserver {
     @override
     void didChangeAppLifecycleState(AppLifecycleState state) {
       if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
         // 通知 PlayerModel 进入降级
         playerModel.onBackground();
       } else if (state == AppLifecycleState.resumed) {
         playerModel.onForeground();
       }
     }
   }
   ```
2. `PlayerModel.onBackground()` 行为：
   - 暂停/隐藏非必要 UI 重建（由 ChangeNotifier 自身收敛）
   - 主动清空图片内存缓存：`PaintingBinding.instance.imageCache.clear()`
   - `defaultCacheManager` 过期文件清理（可选）
3. `PlayerModel.onForeground()`：恢复 `notifyListeners()` 让 UI 重建。

#### 3.2.5 AppDatabase 单例化

**目标**：消除 M10。

**改动文件**：`lib/database/database.dart`、所有 `final db = AppDatabase();` 处。

1. `AppDatabase` 改为：
   ```dart
   class AppDatabase extends _$AppDatabase {
     AppDatabase._(QueryExecutor e) : super(e);
     static AppDatabase? _instance;
     factory AppDatabase() => _instance ??= AppDatabase._(_openConnection());
     @override
     int get schemaVersion => 1;
   }
   ```
2. 仅在 `AppLifecycleState.detached` 时 `_instance?.close(); _instance = null;`。
3. 字段 `final db = AppDatabase();` 改为 `final db = AppDatabase();` 仍可，但所有访问走同一连接。

### 3.3 播放列表持久化（任务 2）

**目标**：保证任何时候关闭/崩溃，下次打开仍能恢复完整播放列表与当前曲目。

**改动文件**：`lib/modules/player/instance.dart`、`lib/modules/player/model.dart`、`lib/modules/data_sync/data_sync.dart`。

#### 3.3.1 写库同步

- `BBPlayer.play(music)` 在 `addPlayerList([music])` 处 **改为 `await addPlayerList([music])`**，消除 P2 竞态。
- `BBPlayer.addPlayerList` 内部：先 `playerList.addAll` → 再 `db.managers.playerListEntity.bulkCreate` → 完成后再返回。
- `BBPlayer.removePlayerList` / `clearPlayerList` 同理。

#### 3.3.2 启动时真正加载 playerList

修复 P1：把 `instance.dart` `_initLocalStorage` 末尾的 `reloadPlayerList();` 改为：
```dart
await reloadPlayerList();  // 已经有 async，但目前 init 中漏了 await
```
并在 `_initLocalStorage` 开头加日志/兜底：如果 `reloadPlayerList` 后 `playerList` 仍为空但 `current != null`，把 `current` 加入 `playerList`（保底）。

#### 3.3.3 写库兜底

- 增加 `BBPlayer._persistPlayerList()`：将内存 `playerList` 全量同步到 `PlayerListEntity`（`isReplace=true` 模式），在以下时机调用：
  - `addPlayerList` / `removePlayerList` / `clearPlayerList` 之后
  - 应用进入 `paused` 时
  - 启动恢复 `current` 之前
- 这样即使中途崩溃，下次启动从 DB 至少能拿到"上次操作后的全集"。

#### 3.3.4 历史/进度合并写库

- `_updateLocalStorage` 中除了 current/mode/history，再把 `playerList.map((e) => jsonEncode(e))` 也写到 `SharedPreferences.playerList`（双写），作为 DB 损坏/迁移失败时的兜底。
- 启动时优先 DB，DB 为空再用 SharedPreferences。

### 3.4 验证标准

完成上述修复后，需满足：

| 任务 | 验证方法 |
| --- | --- |
| 内存不增长 | 在 Windows 端连续播放 50 首歌，使用 DevTools Memory 面板的 heap timeline，确认 Rss/Heap 无持续增长；切歌间隙应观察到回落 |
| 流订阅无泄漏 | 反复切歌 100 次，`StreamSubscription` 总数应保持恒定（可在 `BBPlayer._subs.add` 处加计数埋点） |
| 播放列表持久化 | 场景 A：搜索一首歌 → 播放 → 立即 Cmd+Q / Task Manager End Process → 重启 → 应能恢复列表与当前曲目；场景 B：导入歌单 → 播放第一首 → End Process → 重启 → 列表应恢复 |
| 图片缓存受控 | 进入后台再返回，DevTools 截图看 imageCache 数量下降 |

### 3.5 实施顺序

1. **先行准备**：建立 `AppDatabase` 单例、注册 `WidgetsBindingObserver`（基础设施，影响所有改动）
2. **修复流订阅泄漏**（3.2.1）：最小改动、独立可验证
3. **重构 BBMusicSource 去掉 `_bytes`**（3.2.2）：核心内存点
4. **修复播放列表持久化**（3.3.1 → 3.3.4）
5. **图片缓存 + 后台降级**（3.2.3 / 3.2.4）
6. **DevTools 内存 profiling 验证**

### 3.6 范围外（明确不做）

- 不重构播放器状态管理为 Riverpod/Bloc（与任务无关）
- 不修改 just_audio_media_kit / media_kit 后端选型
- 不动 UI 设计、主题色
- 不动歌单广场/云端同步逻辑
- 不删除 `print` 之外的注释代码（仅清理本次新引入或与内存问题直接相关的死代码）

---

## 4. 关键文件索引

| 关注点 | 文件 |
| --- | --- |
| 播放器核心逻辑 | [instance.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/modules/player/instance.dart) |
| 播放器状态层 | [model.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/modules/player/model.dart) |
| AudioService 集成 | [service.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/modules/player/service.dart) |
| 音频源 + 缓存 | [source.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/modules/player/source.dart) |
| 入口与 Provider | [main.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/main.dart) |
| 数据库 | [database.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/database/database.dart) |
| 播放列表实体 | [player_list.entity.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/database/entity/player_list.entity.dart) |
| 老数据迁移 | [data_sync.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/modules/data_sync/data_sync.dart) |
| 缓存键 | [cache_key.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/constants/cache_key.dart) |
| 节流工具 | [utils.dart](file:///d:/Program/WebProjects/bilimusic/fluttermusic/lib/utils/utils.dart) |
