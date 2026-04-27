import 'dart:async';

import 'package:bbmusic/modules/user_music_order/webdav/constants.dart';
import 'package:flutter/material.dart';

class WebDAVConfigView extends StatefulWidget {
  final Map<String, dynamic>? value;
  final Function(Map<String, dynamic>) onChange;

  const WebDAVConfigView({
    super.key,
    required this.value,
    required this.onChange,
  });

  @override
  State<WebDAVConfigView> createState() => _WebDAVConfigViewState();
}

class _WebDAVConfigViewState extends State<WebDAVConfigView> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _filepathController = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    _urlController.text = widget.value?[WebDAVOriginConst.configFieldUrl] ?? '';
    _usernameController.text =
        widget.value?[WebDAVOriginConst.configFieldUsername] ?? '';
    _passwordController.text =
        widget.value?[WebDAVOriginConst.configFieldPassword] ?? '';
    _filepathController.text =
        widget.value?[WebDAVOriginConst.configFieldFilepath] ?? '';
  }

  _changeHandler() async {
    if (_timer != null) _timer!.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      widget.onChange({
        WebDAVOriginConst.configFieldUrl: _urlController.text,
        WebDAVOriginConst.configFieldUsername: _usernameController.text,
        WebDAVOriginConst.configFieldPassword: _passwordController.text,
        WebDAVOriginConst.configFieldFilepath: _filepathController.text,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            label: Text("WebDAV 地址"),
            hintText: "例如: https://example.com/dav",
          ),
          onChanged: (e) {
            _changeHandler();
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            label: Text("用户名"),
          ),
          onChanged: (e) {
            _changeHandler();
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            label: Text("密码"),
          ),
          onChanged: (e) {
            _changeHandler();
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _filepathController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            label: Text("文件路径"),
            hintText: "例如: bbmusic/playlist.json",
          ),
          onChanged: (e) {
            _changeHandler();
          },
        ),
      ],
    );
  }
}
