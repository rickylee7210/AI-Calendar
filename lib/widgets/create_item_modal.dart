import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_item.dart';
import '../theme/app_icons.dart';

class CreateItemModal extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<CalendarItem> onSave;
  final VoidCallback? onClose;

  const CreateItemModal({
    super.key,
    required this.selectedDate,
    required this.onSave,
    this.onClose,
  });

  @override
  State<CreateItemModal> createState() => _CreateItemModalState();
}

class _CreateItemModalState extends State<CreateItemModal> {
  final _titleCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  bool _isTodo = true;
  late DateTime _date;
  TimeOfDay _startTime = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isAllDay = false;
  int _reminder = 15;

  @override
  void initState() {
    super.initState();
    _date = widget.selectedDate;
    final now = TimeOfDay.now();
    _startTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
    _endTime = TimeOfDay(hour: (now.hour + 2) % 24, minute: 0);
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  bool get _canSave => _titleCtl.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    final dt = _isTodo ? _date
        : DateTime(_date.year, _date.month, _date.day, _startTime.hour, _startTime.minute);
    final et = (!_isTodo)
        ? DateTime(_date.year, _date.month, _date.day, _endTime.hour, _endTime.minute)
        : null;
    widget.onSave(CalendarItem(
      title: _titleCtl.text.trim(),
      dateTime: dt,
      endTime: et,
      type: _isTodo ? ItemType.todo : ItemType.schedule,
      reminderMinutes: _isTodo ? 0 : _reminder,
      isAllDay: _isAllDay,
      note: _noteCtl.text.trim().isEmpty ? null : _noteCtl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Fixed top: handle + navBar + tabs
          _buildHandle(),
          _buildNavBar(),
          _buildTabs(),
          // Scrollable form content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: keyboardHeight + 40),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  _buildTitleInput(),
                  const SizedBox(height: 12),
                  if (_isTodo) _buildTodoFields(),
                  if (!_isTodo) _buildScheduleFields(),
                  const SizedBox(height: 12),
                  _buildNoteInput(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 拖拽手柄 — 60x3 灰条
  Widget _buildHandle() {
    return Container(
      height: 24,
      alignment: Alignment.center,
      child: Container(
        width: 60, height: 3,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  /// 导航栏 — ✕ 标题 ✓
  Widget _buildNavBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center title
          Text(
            _isTodo ? '创建待办' : '创建日程',
            style: const TextStyle(
              fontFamily: 'MiSans', fontSize: 18,
              fontWeight: FontWeight.w500, color: Colors.black, height: 1.0,
            ),
          ),
          // Left close
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: widget.onClose ?? () => Navigator.of(context).pop(),
              child: SizedBox(
                width: 44, height: 44,
                child: Center(child: Text(
                  String.fromCharCode(0xF0009), // 󰀉 close
                  style: const TextStyle(
                    fontFamily: 'HyperOS Symbols', fontSize: 21,
                    fontWeight: FontWeight.w300, color: Colors.black, height: 1.0,
                  ),
                )),
              ),
            ),
          ),
          // Right confirm
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _canSave ? _save : null,
              child: SizedBox(
                width: 44, height: 44,
                child: Center(child: Opacity(
                  opacity: _canSave ? 1.0 : 0.3,
                  child: Text(
                    String.fromCharCode(0xF0008), // 󰀈 check
                    style: const TextStyle(
                      fontFamily: 'HyperOS Symbols', fontSize: 21,
                      fontWeight: FontWeight.w300, color: Colors.black, height: 1.0,
                    ),
                  ),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 分段按钮 — 毛玻璃胶囊容器，选中项灰色背景
  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1000),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.8),
          color: Colors.white.withValues(alpha: 0.4),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 40),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Row(children: [
          Expanded(child: _segmentTab('待办', _isTodo, () => setState(() => _isTodo = true))),
          Expanded(child: _segmentTab('日程', !_isTodo, () => setState(() => _isTodo = false))),
        ]),
      ),
    );
  }

  Widget _segmentTab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.black.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'MiSans', fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        )),
      ),
    );
  }

  /// 标题输入框 — 蓝色竖线 + placeholder
  Widget _buildTitleInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _titleCtl,
            autofocus: true,
            style: const TextStyle(fontFamily: 'MiSans', fontSize: 17, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: _isTodo ? '输入任务' : '输入日程',
              hintStyle: TextStyle(
                fontFamily: 'MiSans', fontSize: 17, fontWeight: FontWeight.w500,
                color: Colors.black.withValues(alpha: 0.3),
              ),
              border: InputBorder.none, isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => setState(() {}),
          )),
        ]),
      ),
    );
  }

  /// 待办字段 — 日期
  Widget _buildTodoFields() {
    return _listRow(
      '日期',
      DateFormat('yyyy-MM-dd').format(_date),
      onTap: () => _pickDate(),
      roundTop: true, roundBottom: true,
    );
  }

  /// 日程字段 — 日期、开始、结束、全天、提醒
  Widget _buildScheduleFields() {
    return Column(children: [
      _listRow('日期', DateFormat('yyyy-MM-dd').format(_date),
        onTap: _pickDate, roundTop: true, showArrow: true),
      _listRow('开始时间', _startTime.format(context),
        onTap: () => _pickTime(true), showArrow: true),
      _listRow('结束时间', _endTime.format(context),
        onTap: () => _pickTime(false), showArrow: true),
      _switchRow('全天', _isAllDay, (v) => setState(() => _isAllDay = v)),
      _listRow('提醒', _reminderLabel(), onTap: _pickReminder, roundBottom: true),
    ]);
  }

  /// 备注输入框
  Widget _buildNoteInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: TextField(
          controller: _noteCtl,
          style: const TextStyle(fontFamily: 'MiSans', fontSize: 17, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: '备注',
            hintStyle: TextStyle(
              fontFamily: 'MiSans', fontSize: 17, fontWeight: FontWeight.w500,
              color: Colors.black.withValues(alpha: 0.3),
            ),
            border: InputBorder.none, isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  /// 列表行 — 白底 56px, MiSans Medium 17px
  Widget _listRow(String label, String value, {
    VoidCallback? onTap, bool roundTop = false, bool roundBottom = false,
    bool showArrow = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: roundTop ? const Radius.circular(20) : Radius.zero,
              bottom: roundBottom ? const Radius.circular(20) : Radius.zero,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text(label, style: const TextStyle(
              fontFamily: 'MiSans', fontSize: 17, fontWeight: FontWeight.w400,
              color: Colors.black,
            )),
            const Spacer(),
            Text(value, style: TextStyle(
              fontFamily: 'MiSans', fontSize: 14, fontWeight: FontWeight.w400,
              color: Colors.black.withValues(alpha: 0.4),
            )),
            if (showArrow) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: Colors.black.withValues(alpha: 0.3)),
            ],
          ]),
        ),
      ),
    );
  }

  /// 开关行
  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 56, color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text(label, style: const TextStyle(
            fontFamily: 'MiSans', fontSize: 17, fontWeight: FontWeight.w400,
            color: Colors.black,
          )),
          const Spacer(),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 49, height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: value ? const Color(0xFF3482FF) : Colors.black.withValues(alpha: 0.15),
              ),
              padding: const EdgeInsets.all(4),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  String _reminderLabel() {
    return switch (_reminder) {
      0 => '无提醒',
      5 => '提前5分钟',
      15 => '提前15分钟',
      30 => '提前30分钟',
      60 => '提前1小时',
      1440 => '提前1天',
      _ => '提前${_reminder}分钟',
    };
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (t != null) setState(() => isStart ? _startTime = t : _endTime = t);
  }

  void _pickReminder() {
    final options = [
      (0, '无提醒'), (5, '提前5分钟'), (15, '提前15分钟'),
      (30, '提前30分钟'), (60, '提前1小时'), (1440, '提前1天'),
    ];
    showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: options.map((o) => ListTile(
        title: Text(o.$2, style: const TextStyle(fontFamily: 'MiSans')),
        trailing: _reminder == o.$1 ? const Icon(Icons.check, color: Color(0xFF3482FF)) : null,
        onTap: () { setState(() => _reminder = o.$1); Navigator.pop(context); },
      )).toList()),
    ));
  }
}
