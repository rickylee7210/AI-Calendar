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
    final done = widget.item.isCompleted;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
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
                GestureDetector(
                  onTap: () => widget.onToggle(widget.item.id),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: done
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: done
                        ? Icon(Icons.check, size: 12,
                            color: Colors.black.withValues(alpha: 0.3))
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.title,
                    style: TextStyle(
                      fontFamily: 'MiSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: done
                      ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.87),
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
