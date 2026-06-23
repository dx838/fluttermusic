import 'package:bbmusic/constants/cache_key.dart';
import 'package:bbmusic/modules/setting/local_data.dart';
import 'package:bbmusic/modules/setting/music_order_origin/list_view.dart';
import 'package:bbmusic/theme/theme_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

final LocalDataManage localDataManage = LocalDataManage();

class SettingView extends StatelessWidget {
  const SettingView({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text('歌单源设置'),
            leading: const Icon(Icons.trip_origin_outlined),
            minTileHeight: 60,
            onTap: () {
              navigator.push(
                MaterialPageRoute(
                  builder: (context) {
                    return const MusicOrderOriginSetting();
                  },
                ),
              );
            },
          ),
          const SizedBox(
            height: 10,
          ),
          const ListTile(
            minTileHeight: 30,
            title: Text(
              "其他配置",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const _ThemeSettingTile(),
          ListTile(
            title: const Text("数据导入"),
            leading: const Icon(Icons.upload),
            onTap: () {
              localDataManage.import(context);
            },
          ),
          ListTile(
            title: const Text("数据导出"),
            leading: const Icon(Icons.download),
            onTap: () {
              localDataManage.export(context);
            },
          ),
          ListTile(
            title: const Text("帮助"),
            leading: const Icon(Icons.help),
            onTap: () {
              launchUrl(
                Uri.parse("https://juejin.cn/post/7431454931264274469"),
              );
            },
          ),
          ListTile(
            title: const Text("关于哔哔音乐"),
            leading: const Icon(Icons.info),
            onTap: () {
              launchUrl(
                Uri.parse("https://juejin.cn/post/7414129923633905675"),
              );
            },
          ),
          ListTile(
            title: const Text("清理缓存"),
            leading: const Icon(Icons.cleaning_services),
            onTap: () async {
              final localStorage = await SharedPreferences.getInstance();
              localStorage.remove(CacheKey.isSyncDB);
            },
          ),
        ],
      ),
    );
  }
}

/// 主题设置入口
class _ThemeSettingTile extends StatelessWidget {
  const _ThemeSettingTile();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModel>(
      builder: (context, themeModel, child) {
        final modeLabel = switch (themeModel.mode) {
          ThemeMode.light => '浅色（白天）',
          ThemeMode.dark => '深色（黑夜）',
          ThemeMode.system => '跟随系统',
          ThemeMode.timed => '定时切换',
        };

        return ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('主题'),
          subtitle: Text(
            modeLabel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => _ThemeDialog(),
            );
          },
        );
      },
    );
  }
}

class _ThemeDialog extends StatefulWidget {
  @override
  State<_ThemeDialog> createState() => _ThemeDialogState();
}

class _ThemeDialogState extends State<_ThemeDialog> {
  late ThemeMode _selectedMode;
  late int _lightStartHour;
  late int _lightStartMinute;
  late int _darkStartHour;
  late int _darkStartMinute;

  @override
  void initState() {
    super.initState();
    final themeModel = context.read<ThemeModel>();
    _selectedMode = themeModel.mode;
    _lightStartHour = themeModel.lightStartHour;
    _lightStartMinute = themeModel.lightStartMinute;
    _darkStartHour = themeModel.darkStartHour;
    _darkStartMinute = themeModel.darkStartMinute;
  }

  @override
  Widget build(BuildContext context) {
    final themeModel = context.read<ThemeModel>();
    final showTimePickers = _selectedMode == ThemeMode.timed;

    return AlertDialog(
      title: const Text('主题设置'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRadioListTile(
              title: '浅色（白天）',
              icon: Icons.light_mode,
              value: ThemeMode.light,
              groupValue: _selectedMode,
              onChanged: (v) => setState(() => _selectedMode = v),
            ),
            _buildRadioListTile(
              title: '深色（黑夜）',
              icon: Icons.dark_mode,
              value: ThemeMode.dark,
              groupValue: _selectedMode,
              onChanged: (v) => setState(() => _selectedMode = v),
            ),
            _buildRadioListTile(
              title: '跟随系统',
              icon: Icons.brightness_auto,
              value: ThemeMode.system,
              groupValue: _selectedMode,
              onChanged: (v) => setState(() => _selectedMode = v),
            ),
            _buildRadioListTile(
              title: '定时切换',
              icon: Icons.schedule,
              value: ThemeMode.timed,
              groupValue: _selectedMode,
              onChanged: (v) => setState(() => _selectedMode = v),
            ),
            if (showTimePickers) ...[
              const SizedBox(height: 10),
              _TimePickerRow(
                label: '白天开始',
                hour: _lightStartHour,
                minute: _lightStartMinute,
                onChanged: (h, m) {
                  setState(() {
                    _lightStartHour = h;
                    _lightStartMinute = m;
                  });
                },
              ),
              const SizedBox(height: 8),
              _TimePickerRow(
                label: '黑夜开始',
                hour: _darkStartHour,
                minute: _darkStartMinute,
                onChanged: (h, m) {
                  setState(() {
                    _darkStartHour = h;
                    _darkStartMinute = m;
                  });
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            await themeModel.setMode(_selectedMode);
            if (_selectedMode == ThemeMode.timed) {
              await themeModel.setLightStart(
                hour: _lightStartHour,
                minute: _lightStartMinute,
              );
              await themeModel.setDarkStart(
                hour: _darkStartHour,
                minute: _darkStartMinute,
              );
            }
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildRadioListTile({
    required String title,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode groupValue,
    required ValueChanged<ThemeMode> onChanged,
  }) {
    return RadioListTile<ThemeMode>(
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  final String label;
  final int hour;
  final int minute;
  final ValueChanged<int, int> onChanged;

  const _TimePickerRow({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: hour, minute: minute),
              );
              if (picked != null) {
                onChanged(picked.hour, picked.minute);
              }
            },
            child: Text(
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
            ),
          ),
        ),
      ],
    );
  }
}
