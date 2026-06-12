import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用说明'),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade900,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('基本操作', [
            _item('新建人物', '在首页点击右下角 + 按钮，输入人物名称'),
            _item('删除人物', '进入人物页面后，点击右上角删除图标'),
            _item('新建条目', '在人物页面点击 + 按钮，输入自定义条目名称'),
            _item('新建招式', '在条目列表页面点击 + 按钮，输入招式名称（可选）'),
          ]),
          _section('编辑招式', [
            _item('添加步骤', '将下方的方向或拳脚按钮拖拽到编辑区'),
            _item('删除步骤', '点击步骤右侧的 X 按钮删除'),
            _item('拖拽排序', '长按步骤左侧的拖拽手柄可调整顺序'),
            _item('添加备注', '在编辑区下方的备注输入框中输入'),
            _item('命名招式', '在编辑区顶部的输入框中设置招式名称'),
          ]),
          _section('招式模板', [
            _item('新建模板', '在人物页面上方点击"新建"，输入模板名称'),
            _item('编辑模板', '点击模板 chip 进入编辑页面'),
            _item('使用模板', '在招式编辑器底部的"模板"区域拖拽模板到编辑区'),
            _item('保存选区为模板',
                '在招式编辑器中点击步骤进行选区，选好后点击保存图标'),
            _item('删除模板',
                '在模板编辑页面点击删除图标，或长按模板 chip 删除'),
          ]),
          _section('数字模式', [
            _item('切换模式', '在人物页面点击右上角箭头/数字图标切换'),
            _item('方向对应',
                '7=↖ 8=↑ 9=↗  4=← 5=中立 6=→  1=↙ 2=↓ 3=↘'),
            _item('拳脚表示',
                '无方向的拳脚显示为 5LP、5MK 等（站立状态）'),
          ]),
          _section('数据管理', [
            _item('导入数据', '在首页点击导入图标，选择 JSON 文件'),
            _item('导出数据', '在首页点击导出图标，保存 JSON 文件'),
            _item('导出PDF',
                '在人物页面点击 PDF 图标，导出该人物的所有招式'),
            _item('自动保存', '所有编辑操作会自动保存，无需手动保存'),
          ]),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'SF6 招式笔记 v1.0',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...items,
        ],
      ),
    );
  }

  Widget _item(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            margin: const EdgeInsets.only(top: 7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
