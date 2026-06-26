import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_data_provider.dart';
import 'character_screen.dart';
import 'help_screen.dart';
import 'template_library_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  Future<void> _showAddCharacterDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建人物'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '人物名称',
            hintText: '例如: 隆, 卢克',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name != null) {
      ref.read(appDataProvider.notifier).addCharacter(name);
    }
  }

  Future<void> _importData({required bool merge}) async {
    final notifier = ref.read(appDataProvider.notifier);
    final success =
        merge ? await notifier.mergeImportData() : await notifier.importData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? (merge ? '合并导入成功' : '导入成功')
              : (merge ? '合并导入失败' : '导入失败')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// Show a popup menu to choose import mode: replace or merge.
  Future<void> _showImportMenu() async {
    final choice = await showMenu<_ImportMode>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 0, 0),
      items: const [
        PopupMenuItem(
          value: _ImportMode.replace,
          child: ListTile(
            leading: Icon(Icons.upload_outlined),
            title: Text('替换导入'),
            subtitle: Text('用所选文件完全覆盖当前数据'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: _ImportMode.merge,
          child: ListTile(
            leading: Icon(Icons.merge_type),
            title: Text('合并导入'),
            subtitle: Text('按 id 合并，仅新增缺失项，保留现有数据'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
    if (choice == null) return;
    await _importData(merge: choice == _ImportMode.merge);
  }

  Future<void> _exportData() async {
    final success = await ref.read(appDataProvider.notifier).exportData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '导出成功' : '导出取消或失败'),
          backgroundColor: success ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SF6 招式笔记',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade900,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '使用说明',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: '通用招式模板',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TemplateLibraryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.upload_outlined),
            tooltip: '导入',
            onPressed: _showImportMenu,
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: '导出',
            onPressed: _exportData,
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: data.characters.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_martial_arts,
                            size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('还没有人物',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey.shade500)),
                        const SizedBox(height: 8),
                        Text('点击 + 号添加你的第一个人物',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: data.characters.length,
                    itemBuilder: (context, index) {
                      final character = data.characters[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            character.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${character.entries.length} 个条目',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade500),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: Colors.grey),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CharacterScreen(
                                  characterId: character.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCharacterDialog,
        backgroundColor: Colors.grey.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

enum _ImportMode { replace, merge }

