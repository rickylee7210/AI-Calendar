import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_item.dart';

class CalendarItemCard extends StatefulWidget {
  final CalendarItem item;
  final String recognizedText;
  final ValueChanged<CalendarItem> onConfirm;
  final VoidCallback onCancel;

  const CalendarItemCard({
    super.key,
    required this.item,
    required this.recognizedText,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<CalendarItemCard> createState() => _CalendarItemCardState();
}

class _CalendarItemCardState extends State<CalendarItemCard> {
  late TextEditingController _titleCtl;
  late DateTime? _dateTime;
  late ItemType _type;
  late int _reminder;

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController(text: widget.item.title);
    _dateTime = widget.item.dateTime;
    _type = widget.item.type;
    _reminder = widget.item.reminderMinutes;
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    super.dispose();
  }

  String _typeLabel(ItemType t) => switch (t) {
    ItemType.schedule => '日程',
    ItemType.todo => '待办',
    ItemType.reminder => '提醒',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recognized text
          Text(
            widget.recognizedText,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.5),
              fontFamily: 'MiSans',
            ),
          ),
          const SizedBox(height: 12),
          // Title
          TextField(
            controller: _titleCtl,
            style: const TextStyle(fontFamily: 'MiSans', fontSize: 16),
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          // Date time
          if (_dateTime != null)
            GestureDetector(
              onTap: () => _pickDateTime(context),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(_dateTime!),
                    style: const TextStyle(fontFamily: 'MiSans', fontSize: 15),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // Type
          DropdownButtonFormField<ItemType>(
            value: _type,
            isDense: true,
            decoration: const InputDecoration(
              labelText: '类型',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: ItemType.values.map((t) => DropdownMenuItem(
              value: t,
              child: Text(_typeLabel(t)),
            )).toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 16),
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => widget.onConfirm(CalendarItem(
                  title: _titleCtl.text,
                  dateTime: _dateTime,
                  type: _type,
                  reminderMinutes: _reminder,
                )),
                child: const Text('确认'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? DateTime.now()),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }
}
