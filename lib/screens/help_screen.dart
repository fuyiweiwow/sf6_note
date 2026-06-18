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
            _item('删除人物', '进入人物页面后，点击右上角垃圾桶图标'),
            _item('新建条目', '在人物页面点击 + 按钮，输入自定义条目名称'),
            _item('条目排序', '长按条目卡片左侧的拖拽手柄 (⠿) 上下拖动调整顺序'),
            _item('新建招式', '在条目列表页面点击 + 按钮，输入招式名称（可选）'),
          ]),
          _section('编辑招式', [
            _item('添加步骤', '将下方的方向或拳脚按钮拖拽到编辑区'),
            _item('删除步骤', '长按步骤并拖出编辑区即可删除'),
            _item('步骤排序', '长按步骤并拖动可调整顺序'),
            _item('招式排序', '在条目招式列表中，长按卡片左侧拖拽手柄调整顺序'),
            _item('复制招式', '在招式卡片上点击复制图标，可在其后快速生成相同招式，便于微调'),
            _item('锁定招式', '点击锁图标锁定/解锁，锁定后招式不会被误删或误改'),
            _item('添加备注', '在编辑区下方的备注输入框中输入'),
            _item('命名招式', '在编辑区顶部的输入框中设置招式名称'),
          ]),
          _section('保存选区为模板', [
            _item('第一步：选起点', '在招式编辑器中点击一个步骤，该步骤出现紫色高亮环'),
            _item('第二步：选终点', '再点击另一端的步骤，两点之间的步骤全部选中'),
            _item('保存', '选区确定后右上角出现书签图标，点击输入模板名即可保存'),
            _item('取消选区', '点击右上角 × 图标清空当前选区'),
            _item('重新选区', '已确定选区后再点击任一步骤，会以该步骤为起点重新开始'),
          ]),
          _section('招式模板', [
            _item('新建模板', '在人物页面上方"招式模板"区域点击"新建"，输入名称'),
            _item('编辑模板', '点击模板 chip（含颜色圆点）进入编辑页面'),
            _item('使用模板', '在招式编辑器底部"模板"区域，把模板拖拽到编辑区'),
            _item('模板颜色', '编辑模板时从调色板选择颜色；不选默认黑色'),
            _item('PDF 显示名字', '勾选"导出 PDF 时显示模板名而不是具体指令"'),
            _item('模板备注', '模板备注在 PDF 中显示在括号内末尾 * 之后'),
            _item('删除模板', '长按模板 chip 或在模板编辑页点击删除图标'),
          ]),
          _section('PDF 导出', [
            _item('导出入口', '在人物页面点击右上角 PDF 图标，选择导出模式'),
            _item('三种模式', '方向模式 (↓↘→LP) / 数字模式 (236LP) / 混合模式（两行）'),
            _item('目录书签', '导出的 PDF 自带书签目录，阅读器左侧大纲面板可看到条目与招式，点击即跳转'),
            _item('分页', '每个招式分类（条目）从新的一页开始'),
            _item('颜色规则', '拳脚按力度上色：轻=蓝、中=琥珀、重=红；数字"5"为黑色；模板勾选"显示名字"时整段用模板颜色'),
            _item('模板备注', '勾选显示名字时，备注在括号内末尾 * 之后显示'),
          ]),
          _section('数字模式', [
            _item('切换模式', '在招式列表页点击右上角图标，依次切换 普通→方向→数字→混合'),
            _item('方向对应',
                '7=↖ 8=↑ 9=↗  4=← 5=中立 6=→  1=↙ 2=↓ 3=↘'),
            _item('拳脚表示', '无方向的拳脚显示为 5LP、5MK 等（站立状态）'),
          ]),
          _section('数据管理', [
            _item('导入数据', '在首页点击导入图标，选择 JSON 文件'),
            _item('导出数据', '在首页点击导出图标，保存 JSON 备份文件'),
            _item('自动保存', '所有编辑会自动保存到本地，无需手动保存'),
            _item('数据位置', 'Windows 下保存在"我的文档\\sf6_data.json"'),
          ]),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'SF6 招式笔记 v1.1',
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
