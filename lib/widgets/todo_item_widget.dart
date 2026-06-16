import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../models/todo.dart';
import '../services/theme.dart';

/// 待办列表项（树状结构）
///
/// 交互（按用户最新要求）：
/// - 主行点击 = 编辑
/// - 主行长按 = 删除
/// - 勾选完成 = 播放完成动画后从当前页消失（自动归入"已完成"）
/// - **右滑（QQ 风格）= 露出：删除 / 进入专注模式** 两个操作按钮
/// - 日期修改：在编辑弹层内进行
class TodoItemWidget extends StatefulWidget {
  final Todo todo;
  final VoidCallback onComplete;     // 主任务完成
  final VoidCallback onExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onEnterFocus;   // 进入专注模式
  final void Function(String) onAddSubtask;
  final void Function(String) onCompleteSubtask;
  final void Function(String) onDeleteSubtask;

  const TodoItemWidget({
    super.key,
    required this.todo,
    required this.onComplete,
    required this.onExpand,
    required this.onEdit,
    required this.onDelete,
    required this.onEnterFocus,
    required this.onAddSubtask,
    required this.onCompleteSubtask,
    required this.onDeleteSubtask,
  });

  @override
  State<TodoItemWidget> createState() => _TodoItemWidgetState();
}

class _TodoItemWidgetState extends State<TodoItemWidget> with SingleTickerProviderStateMixin {
  // 颜色条：用于区分不同任务
  static const _accent = [
    AppColors.accent,
    AppColors.purple,
    AppColors.success,
    AppColors.warning,
    AppColors.danger,
    AppColors.accent2,
    AppColors.accent3,
  ];

  // ===== 完成动画 =====
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;
  late final Animation<Offset> _slideAnim;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInCubic),
    );
    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _slideAnim = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.4)).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInCubic),
    );
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _completing) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// 触发完成动画
  void _startCompleteAnim() {
    if (_completing) return;
    setState(() => _completing = true);
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _opacityAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final t = widget.todo;
    return Slidable(
      key: ValueKey('todo-${t.id}'),
      groupTag: 'todo-list',
      // ===== QQ 风格：左滑（endToStart）露出动作按钮 =====
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => widget.onEnterFocus(),
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            icon: Icons.play_arrow,
            label: '专注',
            autoClose: true,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
          ),
          SlidableAction(
            onPressed: (_) => widget.onDelete(),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: '删除',
            autoClose: true,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMainRow(t),
            if (t.isExpanded) _buildSubtaskList(t),
            if (t.isExpanded) _buildAddSubtask(t),
          ],
        ),
      ),
    );
  }

  // ===== 主行 =====
  Widget _buildMainRow(Todo t) {
    return InkWell(
      onTap: widget.onEdit,
      onLongPress: widget.onDelete,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Row(
          children: [
            // 左侧颜色条
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: _accent[t.colorIndex.clamp(0, _accent.length - 1)],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            // 复选框：点击触发完成动画
            GestureDetector(
              onTap: _startCompleteAnim,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _completing ? AppColors.accent : Colors.transparent,
                  border: Border.all(
                    color: _completing ? AppColors.accent : AppColors.textMuted2,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _completing
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // 文字 + 标签
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: TextStyle(
                      color: t.isDone ? AppColors.textMuted : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      decoration: t.isDone ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                  if (t.dueDate != null || (t.tag?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (t.tag?.isNotEmpty ?? false) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.tag!,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (t.dueDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 10, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                DateFormat('MM/dd').format(t.dueDate!),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // 进度提示（子任务）
            if (t.subtasks.isNotEmpty) ...[
              Text(
                '${t.doneSubtaskCount}/${t.subtasks.length}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 4),
            ],
            // 展开/折叠
            if (t.subtasks.isNotEmpty)
              IconButton(
                onPressed: widget.onExpand,
                icon: Icon(
                  t.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  color: AppColors.textMuted,
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  // ===== 子任务列表 =====
  Widget _buildSubtaskList(Todo parent) {
    return Column(
      children: parent.subtasks.map((s) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(40, 0, 8, 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => widget.onCompleteSubtask(s.id),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent,
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: CircleAvatar(radius: 4, backgroundColor: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => widget.onDeleteSubtask(s.id),
                icon: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ===== 添加子任务 =====
  Widget _buildAddSubtask(Todo parent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 4, 8, 12),
      child: InkWell(
        onTap: () => _showAddSubtaskDialog(parent),
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Icons.add, size: 14, color: AppColors.accent),
              SizedBox(width: 6),
              Text('添加子任务', style: TextStyle(color: AppColors.accent, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSubtaskDialog(Todo parent) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加子任务'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '子任务名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('子任务名称不能为空')),
                );
                return;
              }
              widget.onAddSubtask(ctrl.text);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('添加', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
