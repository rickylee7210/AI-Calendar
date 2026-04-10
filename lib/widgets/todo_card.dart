import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoCard extends StatelessWidget {
  final TodoItem item;
  final ValueChanged<String> onToggle;

  const TodoCard({super.key, required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('todo-card-container'),
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.05),
      ),
      padding: const EdgeInsets.only(left: 16, right: 12, top: 10, bottom: 10),
      child: Row(
        children: [
          // Checkbox — 18x18
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: item.isCompleted,
              onChanged: (_) => onToggle(item.id),
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
          // Title — MiSans Medium 16px, opacity 0.87
          Expanded(
            child: Opacity(
              opacity: item.isCompleted ? 0.4 : 0.87,
              child: Text(
                item.title,
                style: TextStyle(
                  fontFamily: 'MiSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                  height: 1.0,
                  decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
