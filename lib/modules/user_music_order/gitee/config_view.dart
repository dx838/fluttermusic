import 'dart:async';

import 'package:bbmusic/modules/user_music_order/gitee/constants.dart';
import 'package:flutter/material.dart';

class GiteeConfigView extends StatefulWidget {
  final Map<String, dynamic>? value;
  final Function(Map<String, dynamic>) onChange;

  const GiteeConfigView({
    super.key,
    required this.value,
    required this.onChange,
  });

  @override
  State<GiteeConfigView> createState() => _GiteeConfigViewState();
}

class _GiteeConfigViewState extends State<GiteeConfigView> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _repoUrlController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _filepathController = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    _repoUrlController.text =
        widget.value?[GiteeOriginConst.configFieldRepoUrl] ?? '';
    _tokenController.text =
        widget.value?[GiteeOriginConst.configFieldToken] ?? '';
    _branchController.text =
        widget.value?[GiteeOriginConst.configFieldBranch] ?? '';
    _filepathController.text =
        widget.value?[GiteeOriginConst.configFieldFilepath] ?? '';
  }

  _changeHandler() async {
    if (_timer != null) _timer!.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      widget.onChange({
        GiteeOriginConst.configFieldRepoUrl: _repoUrlController.text,
        GiteeOriginConst.configFieldToken: _tokenController.text,
        GiteeOriginConst.configFieldBranch: _branchController.text,
        GiteeOriginConst.configFieldFilepath: _filepathController.text
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _repoUrlController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            label: Text("仓库地址"),
          ),
          onChanged: (e) {
            _changeHandler();
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _tokenController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            label: Text("Token"),
          ),
          onChanged: (e) {
            _changeHandler();
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _branchController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            label: Text("分支"),
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
          ),
          onChanged: (e) {
            _changeHandler();
          },
        ),
      ],
    );
  }
}
