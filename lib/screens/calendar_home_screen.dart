import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calendar_item.dart';
import '../models/todo_item.dart';
import '../providers/voice_input_provider.dart';
import '../services/notification_service.dart';
import '../widgets/calendar_picker_modal.dart';
import '../widgets/create_item_modal.dart';
import '../theme/app_icons.dart';
import '../widgets/week_strip.dart';
import '../widgets/todo_card.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/voice_overlay.dart';

class CalendarHomeScreen extends StatefulWidget {
  const CalendarHomeScreen({super.key});

  @override
  State<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends State<CalendarHomeScreen> {
  late DateTime _selectedDate;
  final Map<String, List<CalendarItem>> _itemsCache = {};
  final Map<String, Future<List<CalendarItem>>> _futureCache = {};

  static const _centerPage = 10000;
  late PageController _contentPageController;
  late DateTime _baseDate; // 基准日期（初始化时的今天）
  bool _isPageAnimating = false; // 防止 PageView 和 _onDateChanged 循环触发

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _baseDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _contentPageController = PageController(initialPage: _centerPage);
  }

  @override
  void dispose() {
    _contentPageController.dispose();
    super.dispose();
  }

  DateTime _dateForPage(int page) {
    return _baseDate.add(Duration(days: page - _centerPage));
  }

  int _pageForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _centerPage + d.difference(_baseDate).inDays;
  }

  void _onDateChanged(DateTime date) {
    final targetPage = _pageForDate(date);
    final currentPage = _contentPageController.page?.round() ?? _centerPage;
    if (targetPage != currentPage && !_isPageAnimating) {
      _isPageAnimating = true;
      _contentPageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ).then((_) => _isPageAnimating = false);
    }
    setState(() => _selectedDate = date);
    _loadItems();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _backToToday() {
    _onDateChanged(DateTime.now());
  }

  String get _monthTitle => '${_selectedDate.month}月';

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  Future<List<CalendarItem>> _loadItemsForDate(DateTime date) {
    final key = _dateKey(date);
    // 返回缓存的 Future，避免 FutureBuilder rebuild 时重复创建
    return _futureCache.putIfAbsent(key, () async {
      try {
        final provider = context.read<VoiceInputProvider>();
        final items = await provider.db.getByDate(date);
        items.sort((a, b) {
          if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
          if (a.dateTime != null && b.dateTime != null) {
            return a.dateTime!.compareTo(b.dateTime!);
          }
          return 0;
        });
        _itemsCache[key] = items;
        // 限制缓存大小，超过 14 天清最早的
        if (_itemsCache.length > 14) {
          _itemsCache.remove(_itemsCache.keys.first);
          _futureCache.remove(_futureCache.keys.first);
        }
        return items;
      } catch (_) {
        return [];
      }
    });
  }

  Future<void> _loadItems() async {
    final key = _dateKey(_selectedDate);
    _itemsCache.remove(key);
    _futureCache.remove(key);
    if (mounted) setState(() {});
  }

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceInputProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildCalendarSection(),
                _buildDivider(),
                Expanded(
                  child: PageView.builder(
                    controller: _contentPageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (page) {
                      if (!_isPageAnimating) {
                        final date = _dateForPage(page);
                        setState(() => _selectedDate = date);
                        _loadItems();
                      }
                    },
                    itemBuilder: (_, page) {
                      final pageDate = _dateForPage(page);
                      return FutureBuilder<List<CalendarItem>>(
                        future: _loadItemsForDate(pageDate),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final items = snapshot.data!;
                          if (items.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 100),
                                child: Opacity(
                                  opacity: 0.3,
                                  child: const Text('暂无事项', style: TextStyle(fontFamily: 'MiSans', fontSize: 15, color: Colors.black)),
                                ),
                              ),
                            );
                          }
                          // 把同一秒创建的多条 todo 合并成组
                          final grouped = <dynamic>[];
                          final usedIndices = <int>{};
                          for (var i = 0; i < items.length; i++) {
                            if (usedIndices.contains(i)) continue;
                            final ci = items[i];
                            if (ci.type == ItemType.todo && ci.createdAt != null) {
                              // 找同一秒创建的其他 todo
                              final batch = <CalendarItem>[ci];
                              for (var j = i + 1; j < items.length; j++) {
                                if (usedIndices.contains(j)) continue;
                                final cj = items[j];
                                if (cj.type == ItemType.todo &&
                                    cj.createdAt != null &&
                                    ci.createdAt!.difference(cj.createdAt!).inSeconds.abs() <= 1) {
                                  batch.add(cj);
                                  usedIndices.add(j);
                                }
                              }
                              grouped.add(batch.length > 1 ? batch : ci);
                            } else {
                              grouped.add(ci);
                            }
                            usedIndices.add(i);
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                            itemCount: grouped.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final entry = grouped[i];
                              // 合并的多条待办
                              if (entry is List<CalendarItem>) {
                                return _BatchTodoCard(
                                  items: entry,
                                  onToggle: (id) => _toggleItem(id),
                                  onTap: (ci) => _showItemActions(ci),
                                );
                              }
                              final ci = entry as CalendarItem;
                              if (ci.type == ItemType.schedule || ci.type == ItemType.reminder) {
                                return GestureDetector(
                                  onTap: () => _showItemActions(ci),
                                  child: _ScheduleCard(item: ci, onToggle: () => _toggleItem('${ci.id}')),
                                );
                              }
                              return TodoCard(
                                item: TodoItem(id: '${ci.id}', title: ci.title, isCompleted: ci.isCompleted),
                                onToggle: (id) => _toggleItem(id),
                                onTap: () => _showItemActions(ci),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            // 录音态/处理态 overlay — 始终在树中，用 Opacity 控制显隐
            // recording: 显示"正在聆听..."，processing: 显示识别结果
            Positioned.fill(
              child: IgnorePointer(
                ignoring: provider.state != VoiceInputState.recording &&
                    provider.state != VoiceInputState.processing,
                child: AnimatedOpacity(
                  opacity: (provider.state == VoiceInputState.recording ||
                          provider.state == VoiceInputState.processing)
                      ? 1.0
                      : 0.0,
                  // 出现时淡入 200ms，消失时瞬间
                  duration: (provider.state == VoiceInputState.recording ||
                          provider.state == VoiceInputState.processing)
                      ? const Duration(milliseconds: 200)
                      : Duration.zero,
                  child: VoiceOverlay(
                    amplitudeStream: provider.amplitudeStream,
                    inCancelZone: provider.inCancelZone,
                    hintText: provider.recognizedText ?? '正在聆听...',
                    isProcessing: provider.state == VoiceInputState.processing,
                  ),
                ),
              ),
            ),
            // 底部栏：录音时隐藏（opacity 0），但保留在树中维持长按手势
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Opacity(
                opacity: (provider.state == VoiceInputState.recording ||
                        provider.state == VoiceInputState.processing)
                    ? 0.0
                    : 1.0,
                child: _buildBottomSection(provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 71,
      padding: const EdgeInsets.only(left: 20, right: 16, top: 6, bottom: 6),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(_monthTitle, style: const TextStyle(
            fontFamily: 'MiSans', fontSize: 40,
            fontWeight: FontWeight.w400, color: Colors.black, height: 1.0,
          )),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.4),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 40),
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 60, offset: const Offset(0, 24)),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.8),
            ),
            alignment: Alignment.center,
            child: Text(
              String.fromCharCode(AppIcons.settings.codePoint),
              style: const TextStyle(
                fontFamily: 'HyperOS Symbols', fontSize: 21,
                fontWeight: FontWeight.w500, color: Colors.black, height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _weekdays.map((d) => SizedBox(
              width: 51, height: 16,
              child: Center(child: Text(d, style: const TextStyle(
                fontFamily: 'MiSans', fontSize: 12, fontWeight: FontWeight.w400,
                color: Colors.black, letterSpacing: 0.12, height: 1.0,
              ), textAlign: TextAlign.center)),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        WeekStrip(
          selectedDate: _selectedDate,
          onDateChanged: _onDateChanged,
        ),
      ]),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 12),
      child: Center(child: CustomPaint(
        size: const Size(352, 1),
        painter: _DashedLinePainter(color: Colors.black.withValues(alpha: 0.1)),
      )),
    );
  }

  Future<void> _toggleItem(String id) async {
    final dbId = int.tryParse(id);
    if (dbId == null) return;
    final provider = context.read<VoiceInputProvider>();
    await provider.db.toggleComplete(dbId);
    // 完成后取消对应的通知提醒
    try { await NotificationService().cancelReminder(dbId); } catch (_) {}
    _loadItems();
  }

  void _showItemActions(CalendarItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'MiSans', fontSize: 17,
                    fontWeight: FontWeight.w500, color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _editItem(item);
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: const Text('编辑', style: TextStyle(
                              fontFamily: 'MiSans', fontSize: 16,
                              fontWeight: FontWeight.w500, color: Colors.black,
                            )),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _confirmDelete(item);
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: const Text('移除', style: TextStyle(
                              fontFamily: 'MiSans', fontSize: 16,
                              fontWeight: FontWeight.w500, color: Color(0xFFFF3B30),
                            )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editItem(CalendarItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height - 100,
          child: CreateItemModal(
            selectedDate: item.dateTime ?? _selectedDate,
            editItem: item,
            onClose: () => Navigator.pop(ctx),
            onSave: (updated) async {
              Navigator.pop(ctx);
              final provider = context.read<VoiceInputProvider>();
              await provider.db.update(updated);
              // 重新注册通知
              if (updated.type != ItemType.todo && updated.dateTime != null && updated.id != null) {
                try {
                  await NotificationService().cancelReminder(updated.id!);
                  await NotificationService().scheduleReminder(updated);
                } catch (e) {
                  debugPrint('[Notification] 编辑后重注册提醒失败: $e');
                }
              }
              _loadItems();
            },
          ),
        );
      },
    );
  }

  void _confirmDelete(CalendarItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认移除', style: TextStyle(
          fontFamily: 'MiSans', fontSize: 18, fontWeight: FontWeight.w500,
        )),
        content: Text('确定要移除「${item.title}」吗？', style: const TextStyle(
          fontFamily: 'MiSans', fontSize: 15,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(
              fontFamily: 'MiSans', color: Colors.black.withValues(alpha: 0.5),
            )),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (item.id != null) {
                final provider = context.read<VoiceInputProvider>();
                await provider.db.delete(item.id!);
                try { await NotificationService().cancelReminder(item.id!); } catch (_) {}
                _loadItems();
              }
            },
            child: const Text('移除', style: TextStyle(
              fontFamily: 'MiSans', color: Color(0xFFFF3B30),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(VoiceInputProvider p) {
    // Show error snackbar
    if (p.state == VoiceInputState.error && p.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(p.errorMessage!),
            action: SnackBarAction(label: '重试', onPressed: () => p.reset()),
          ),
        );
        p.reset();
      });
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        height: 30,
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF5F8FF).withValues(alpha: 0),
            const Color(0xFFF6F9FF).withValues(alpha: 0.8),
            const Color(0xFFF7FAFF).withValues(alpha: 0.9),
          ],
          stops: const [0.0625, 0.30, 1.0],
        )),
      ),
      Container(
        color: const Color(0xFFF7FAFF).withValues(alpha: 0.9),
        child: BottomActionBar(
          showBackToToday: !_isToday,
          onKeyboardTap: () => _showCreateItem(context),
          onVoiceLongPressStart: () async {
            debugPrint('[UI] 长按开始, state=${p.state}');
            if (p.state == VoiceInputState.idle || p.state == VoiceInputState.error) {
              p.reset();
              await p.startRecording();
            }
          },
          onVoiceLongPressMoveUpdate: (delta) {
            if (p.state == VoiceInputState.recording) {
              p.updateFingerPosition(delta);
            }
          },
          onVoiceLongPressEnd: () async {
            debugPrint('[UI] 长按结束, state=${p.state}, inCancelZone=${p.inCancelZone}');
            if (p.state == VoiceInputState.recording) {
              await p.stopProcessAndSave();
              if (mounted && p.lastSaveSuccess) {
                final savedDate = p.lastSavedDate;
                if (savedDate != null) {
                  _onDateChanged(savedDate);
                } else {
                  _loadItems();
                }
              }
            }
          },
          onCalendarTap: _isToday
              ? () => _showCalendarPicker(context)
              : _backToToday,
        ),
      ),
    ]);
  }

  void _showCreateItem(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height - 100,
          child: CreateItemModal(
            selectedDate: _selectedDate,
            onClose: () => Navigator.pop(ctx),
            onSave: (item) async {
              Navigator.pop(ctx);
              final provider = context.read<VoiceInputProvider>();
              final insertedId = await provider.db.insert(item);
              // 注册通知提醒
              if (item.type != ItemType.todo && item.dateTime != null) {
                try {
                  await NotificationService().scheduleReminder(item.copyWith(id: insertedId));
                } catch (e) {
                  debugPrint('[Notification] 手动创建提醒失败: $e');
                }
              }
              _loadItems();
            },
          ),
        );
      },
    );
  }

  void _showCalendarPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: CalendarPickerModal(
            initialDate: _selectedDate,
            onDateSelected: (date) {
              Navigator.pop(ctx);
              _onDateChanged(date);
            },
          ),
        );
      },
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1..style = PaintingStyle.stroke;
    const dw = 4.0, ds = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dw, 0), paint);
      x += dw + ds;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 批量待办卡片 — 一个卡片内多条可独立勾选的待办
class _BatchTodoCard extends StatelessWidget {
  final List<CalendarItem> items;
  final ValueChanged<String> onToggle;
  final ValueChanged<CalendarItem> onTap;

  const _BatchTodoCard({required this.items, required this.onToggle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.03),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 0.5, color: Colors.black.withValues(alpha: 0.06)),
            GestureDetector(
              onTap: () => onTap(items[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: items[i].isCompleted,
                        onChanged: (_) => onToggle('${items[i].id}'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: items[i].isCompleted ? 0.4 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          items[i].title,
                          style: TextStyle(
                            fontFamily: 'MiSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black.withValues(alpha: 0.87),
                            height: 1.0,
                            decoration: items[i].isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 日程/提醒卡片 — 显示时间段和提醒信息
class _ScheduleCard extends StatelessWidget {
  final CalendarItem item;
  final VoidCallback onToggle;

  const _ScheduleCard({required this.item, required this.onToggle});

  String get _timeRange {
    if (item.dateTime == null) return '';
    final dt = item.dateTime!;
    final start = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final end = item.endTime ?? dt.add(const Duration(hours: 1));
    final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$start - $endStr';
  }

  String get _reminderText {
    if (item.reminderMinutes <= 0) return '';
    if (item.reminderMinutes < 60) return '提前${item.reminderMinutes}分钟提醒';
    return '提前${item.reminderMinutes ~/ 60}小时提醒';
  }

  String get _typeIcon => item.type == ItemType.reminder ? '🔔' : '📅';

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: item.isCompleted ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: AnimatedScale(
        scale: item.isCompleted ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.03),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 小红点指示器 — 放在 18px 宽容器中居中，与待办 checkbox 对齐
          SizedBox(
            width: 18,
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 内容
          Expanded(
            child: Opacity(
              opacity: item.isCompleted ? 0.4 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontFamily: 'MiSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withValues(alpha: 0.87),
                      decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (_timeRange.isNotEmpty) ...[
                        Icon(Icons.access_time, size: 13,
                            color: Colors.black.withValues(alpha: 0.45)),
                        const SizedBox(width: 4),
                        Text(
                          _timeRange,
                          style: TextStyle(
                            fontFamily: 'MiSans', fontSize: 13,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      if (_timeRange.isNotEmpty && _reminderText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('·', style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withValues(alpha: 0.3),
                          )),
                        ),
                      if (_reminderText.isNotEmpty)
                        Text(
                          _reminderText,
                          style: TextStyle(
                            fontFamily: 'MiSans', fontSize: 13,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }
}

/// 虚线圆形 — 日程卡片的勾选框
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final bool checked;
  _DashedCirclePainter({required this.color, required this.checked});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    if (checked) {
      canvas.drawCircle(center, radius, Paint()..color = color);
      final checkPath = Path()
        ..moveTo(size.width * 0.28, size.height * 0.5)
        ..lineTo(size.width * 0.45, size.height * 0.67)
        ..lineTo(size.width * 0.72, size.height * 0.35);
      canvas.drawPath(
        checkPath,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      const dashCount = 12;
      const gapRatio = 0.4;
      final dashAngle = (2 * pi) / dashCount * (1 - gapRatio);
      final gapAngle = (2 * pi) / dashCount * gapRatio;
      for (int i = 0; i < dashCount; i++) {
        final startAngle = i * (dashAngle + gapAngle) - pi / 2;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          dashAngle,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color || old.checked != checked;
}
