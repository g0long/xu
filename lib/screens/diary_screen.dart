import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/diary.dart';
import '../providers/diary_provider.dart';
import '../services/theme.dart';

/// 日记页面
///
/// 位于底栏第 3 项（习惯与专注之间）
/// - 顶部：标题 + 筛选 chips
/// - 列表：按日期分组
/// - FAB：新建日记
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  int _filterIndex = 0; // 0=全部 1=今日 2=本周 3=本月

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(diaryProvider);
    final filtered = _applyFilter(all, _filterIndex);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterChips(),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyDiary()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final d = filtered[i];
                        return _DiaryCard(
                          key: ValueKey(d.id),
                          diary: d,
                          onTap: () => _openEditor(context, d),
                          onDelete: () => _confirmDelete(d),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, null),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.edit, size: 26, color: Colors.white),
      ),
    );
  }

  // ===== 顶部标题 =====
  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(
            '日记',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ===== 筛选 chips =====
  Widget _buildFilterChips() {
    const filters = [
      ('全部', Icons.all_inclusive),
      ('今日', Icons.today),
      ('本周', Icons.view_week),
      ('本月', Icons.calendar_month),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = _filterIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.secondaryBg : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? Colors.transparent : AppColors.divider,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filters[i].$2,
                    size: 16,
                    color: selected ? AppColors.textPrimary : AppColors.textMuted2,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filters[i].$1,
                    style: TextStyle(
                      color: selected ? AppColors.textPrimary : AppColors.textMuted2,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== 过滤逻辑 =====
  List<Diary> _applyFilter(List<Diary> all, int idx) {
    final now = DateTime.now();
    switch (idx) {
      case 1: // 今日
        return all.where((d) {
          return d.date.year == now.year && d.date.month == now.month && d.date.day == now.day;
        }).toList();
      case 2: // 本周
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 7));
        return all.where((d) => !d.date.isBefore(monday) && d.date.isBefore(sunday)).toList();
      case 3: // 本月
        return all.where((d) => d.date.year == now.year && d.date.month == now.month).toList();
      default:
        return all;
    }
  }

  // ===== 编辑器（新增/编辑）=====
  Future<void> _openEditor(BuildContext context, Diary? existing) async {
    final result = await showModalBottomSheet<Diary?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _DiaryEditor(existing: existing),
      ),
    );
    if (result == null) return;

    if (existing == null) {
      await ref.read(diaryProvider.notifier).add(
            date: result.date,
            title: result.title,
            content: result.content,
            mood: result.mood,
            saying: result.saying,
          );
    } else {
      await ref.read(diaryProvider.notifier).update(
            id: existing.id,
            date: result.date,
            title: result.title,
            content: result.content,
            mood: result.mood,
            saying: result.saying,
          );
    }
  }

  Future<void> _confirmDelete(Diary d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除日记'),
        content: const Text('确定要删除这篇日记吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(diaryProvider.notifier).remove(d.id);
    }
  }
}

// ============================================================
// 日记卡片
// ============================================================
class _DiaryCard extends StatelessWidget {
  final Diary diary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DiaryCard({
    super.key,
    required this.diary,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 心情 emoji
                Container(
                  width: 40, height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity( 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(diary.mood, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diary.title.isEmpty ? '(无标题)' : diary.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('yyyy-MM-dd EEEE', 'zh_CN').format(diary.date),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (diary.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                diary.content,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 日记编辑器（弹层）
// ============================================================
class _DiaryEditor extends StatefulWidget {
  final Diary? existing;
  const _DiaryEditor({this.existing});

  @override
  State<_DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<_DiaryEditor> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _sayingCtrl;
  late DateTime _date;
  late String _mood;

  static const _moods = ['😊', '😄', '😐', '😔', '😢', '😡', '🤩', '😴', '🤔', '😎', '🥰', '😴'];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.existing?.content ?? '');
    _sayingCtrl = TextEditingController(text: widget.existing?.saying ?? '');
    _date = widget.existing?.date ?? DateTime.now();
    _mood = widget.existing?.mood ?? '😊';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _sayingCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty && _contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题或内容至少填一项')),
      );
      return;
    }
    final result = Diary(
      id: widget.existing?.id ?? '',
      date: _date,
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      mood: _mood,
      saying: _sayingCtrl.text,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textMuted2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.existing == null ? '写日记' : '编辑日记',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            // 日期
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _pickDate,
                  style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                  child: Text(DateFormat('yyyy-MM-dd').format(_date)),
                ),
              ],
            ),
            // 心情
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _moods.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final m = _moods[i];
                  final selected = m == _mood;
                  return GestureDetector(
                    onTap: () => setState(() => _mood = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40, height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent.withOpacity( 0.2) : AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? AppColors.accent : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(m, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // 标题
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                hintText: '标题（可选）',
                prefixIcon: Icon(Icons.title, size: 18, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            // ★ 一句话金句（最多 20 字，会显示在待办页顶部）
            TextField(
              controller: _sayingCtrl,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: '一句话金句（最多 20 字）',
                counterText: '',
                prefixIcon: const Icon(Icons.format_quote, size: 18, color: AppColors.accent),
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            // 内容
            TextField(
              controller: _contentCtrl,
              maxLines: 6,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: '今天发生了什么...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('保存', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 空状态
// ============================================================
class _EmptyDiary extends StatelessWidget {
  const _EmptyDiary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: AppColors.textMuted2),
          const SizedBox(height: 16),
          const Text('还没有日记', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('点击右下角 ＋ 记录今天的心情与故事',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
