import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoCard extends StatefulWidget {
  final TodoItem item;
  final ValueChanged<String> onToggle;
  final VoidCallback? onTap;

  const TodoCard({super.key, required this.item, required this.onToggle, this.onTap});

  @override
  State<TodoCard> createState() => _TodoCardState();
}

class _TodoCardState extends State<TodoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _entryCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: AnimatedOpacity(
          opacity: widget.item.isCompleted ? 0.4 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedScale(
            scale: widget.item.isCompleted ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                key: const Key('todo-card-container'),
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withValues(alpha: 0.03),
                ),
                padding: const EdgeInsets.only(
                    left: 16, right: 12, top: 10, bottom: 10),
                child: Row(
                  children: [
                    // Checkbox — 18x18
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: widget.item.isCompleted,
                        onChanged: (_) => widget.onToggle(widget.item.id),
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
                    // Title — MiSans Medium 16px
                    Expanded(
                      child: Text(
                        widget.item.title,
                        style: TextStyle(
                          fontFamily: 'MiSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withValues(alpha: 0.87),
                          height: 1.0,
                          decoration: widget.item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
