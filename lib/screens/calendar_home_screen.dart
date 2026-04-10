import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calendar_item.dart';
import '../models/todo_item.dart';
import '../providers/voice_input_provider.dart';
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
  List<CalendarItem> _calendarItems = [];
  bool _loading = true;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadItems());
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

  Future<void> _loadItems() async {
    try {
      final provider = context.read<VoiceInputProvider>();
      final items = await provider.db.getByDate(_selectedDate);
      items.sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        // 日程按时间排序
        if (a.dateTime != null && b.dateTime != null) {
          return a.dateTime!.compareTo(b.dateTime!);
        }
        return 0;
      });
      if (mounted) {
        setState(() {
          _calendarItems = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
                    onPageChanged: (page) {
                      if (!_isPageAnimating) {
                        final date = _dateForPage(page);
                        setState(() => _selectedDate = date);
                        _loadItems();
                      }
                    },
                    itemBuilder: (_, page) {
                      // 只有当前页才用已加载的数据，其他页显示空白（翻过去后会加载）
                      final pageDate = _dateForPage(page);
                      final isCurrent = pageDate.year == _selectedDate.year &&
                          pageDate.month == _selectedDate.month &&
                          pageDate.day == _selectedDate.day;
                      if (isCurrent) {
                        return _buildTodoList();
                      }
                      return const SizedBox.shrink();
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
                  duration: const Duration(milliseconds: 200),
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

  Widget _buildTodoList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_calendarItems.isEmpty) {
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: _calendarItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final ci = _calendarItems[i];
        if (ci.type == ItemType.schedule || ci.type == ItemType.reminder) {
          return _ScheduleCard(item: ci, onToggle: () => _toggleItem('${ci.id}'));
        }
        return TodoCard(
          item: TodoItem(id: '${ci.id}', title: ci.title, isCompleted: ci.isCompleted),
          onToggle: (id) => _toggleItem(id),
        );
      },
    );
  }

  Future<void> _toggleItem(String id) async {
    final dbId = int.tryParse(id);
    if (dbId == null) return;
    final provider = context.read<VoiceInputProvider>();
    await provider.db.toggleComplete(dbId);
    _loadItems();
  }

  Widget _buildProcessingIndicator() {
    return Positioned(
      left: 0, right: 0, bottom: 90,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '处理中...',
                style: TextStyle(
                  fontFamily: 'MiSans', fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CreateItem',
      barrierColor: Colors.black.withValues(alpha: 0.1),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (ctx, _, __) {
        return Stack(
          children: [
            // Tap barrier to close
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            // Drawer: top 100dp to bottom
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: Colors.transparent,
                child: CreateItemModal(
                  selectedDate: _selectedDate,
                  onClose: () => Navigator.pop(ctx),
                  onSave: (item) async {
                    Navigator.pop(ctx);
                    final provider = context.read<VoiceInputProvider>();
                    await provider.db.insert(item);
                    _loadItems();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCalendarPicker(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CalendarPicker',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        );
      },
      pageBuilder: (ctx, _, __) {
        return Stack(
          children: [
            // Tap outside to close
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            // Floating card
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                color: Colors.transparent,
                child: CalendarPickerModal(
                  initialDate: _selectedDate,
                  onDateSelected: (date) {
                    Navigator.pop(ctx);
                    _onDateChanged(date);
                  },
                ),
              ),
            ),
          ],
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.05),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 左侧色条
          Container(
            width: 3,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: item.type == ItemType.reminder
                  ? const Color(0xFFFF9500)
                  : const Color(0xFF3482FF),
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
          // 完成按钮
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: item.isCompleted,
              onChanged: (_) => onToggle(),
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
        ],
      ),
    );
  }
}
