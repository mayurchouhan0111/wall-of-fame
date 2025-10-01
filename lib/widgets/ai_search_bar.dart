import 'package:flutter/material.dart';

class AISearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final List<String> suggestions;

  const AISearchBar({
    Key? key,
    required this.onSearch,
    this.suggestions = const [],
  }) : super(key: key);

  @override
  _AISearchBarState createState() => _AISearchBarState();
}

class _AISearchBarState extends State<AISearchBar>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: TextField(
          controller: _controller,
          onSubmitted: widget.onSearch,
          decoration: InputDecoration(
            hintText: 'Describe your perfect wallpaper...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.purple.shade400,
                    size: 24,
                  ),
                );
              },
            ),
            suffixIcon: IconButton(
              icon: Icon(Icons.search, color: Colors.purple.shade400),
              onPressed: () => widget.onSearch(_controller.text),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }
}
