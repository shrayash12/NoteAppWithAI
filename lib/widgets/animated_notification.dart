import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum NotificationType {
  created,
  updated,
  pinned,
  unpinned,
  favorite,
  unfavorite,
  locked,
  unlocked,
  deleted,
  success,
  error,
}

class AnimatedNotification {
  static void show(
    BuildContext context, {
    required NotificationType type,
    String? customMessage,
  }) {
    final config = _getConfig(type, customMessage);

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _AnimatedNotificationContent(
          icon: config.icon,
          title: config.title,
          color: config.color,
          iconColor: config.iconColor,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static _NotificationConfig _getConfig(NotificationType type, String? customMessage) {
    switch (type) {
      case NotificationType.created:
        return _NotificationConfig(
          icon: Icons.add_circle,
          title: customMessage ?? 'Note Created',
          color: const Color(0xFF8B5CF6),
          iconColor: Colors.white,
        );
      case NotificationType.updated:
        return _NotificationConfig(
          icon: Icons.check_circle,
          title: customMessage ?? 'Note Updated',
          color: const Color(0xFF22C55E),
          iconColor: Colors.white,
        );
      case NotificationType.pinned:
        return _NotificationConfig(
          icon: Icons.push_pin,
          title: customMessage ?? 'Note Pinned',
          color: const Color(0xFF3B82F6),
          iconColor: Colors.white,
        );
      case NotificationType.unpinned:
        return _NotificationConfig(
          icon: Icons.push_pin_outlined,
          title: customMessage ?? 'Note Unpinned',
          color: const Color(0xFF64748B),
          iconColor: Colors.white,
        );
      case NotificationType.favorite:
        return _NotificationConfig(
          icon: Icons.star,
          title: customMessage ?? 'Added to Favorites',
          color: const Color(0xFFF59E0B),
          iconColor: Colors.white,
        );
      case NotificationType.unfavorite:
        return _NotificationConfig(
          icon: Icons.star_outline,
          title: customMessage ?? 'Removed from Favorites',
          color: const Color(0xFF64748B),
          iconColor: Colors.white,
        );
      case NotificationType.locked:
        return _NotificationConfig(
          icon: Icons.lock,
          title: customMessage ?? 'Note Locked',
          color: const Color(0xFFEC4899),
          iconColor: Colors.white,
        );
      case NotificationType.unlocked:
        return _NotificationConfig(
          icon: Icons.lock_open,
          title: customMessage ?? 'Note Unlocked',
          color: const Color(0xFF06B6D4),
          iconColor: Colors.white,
        );
      case NotificationType.deleted:
        return _NotificationConfig(
          icon: Icons.delete,
          title: customMessage ?? 'Note Deleted',
          color: const Color(0xFFEF4444),
          iconColor: Colors.white,
        );
      case NotificationType.success:
        return _NotificationConfig(
          icon: Icons.check_circle,
          title: customMessage ?? 'Success',
          color: const Color(0xFF22C55E),
          iconColor: Colors.white,
        );
      case NotificationType.error:
        return _NotificationConfig(
          icon: Icons.error,
          title: customMessage ?? 'Error',
          color: const Color(0xFFEF4444),
          iconColor: Colors.white,
        );
    }
  }
}

class _NotificationConfig {
  final IconData icon;
  final String title;
  final Color color;
  final Color iconColor;

  _NotificationConfig({
    required this.icon,
    required this.title,
    required this.color,
    required this.iconColor,
  });
}

class _AnimatedNotificationContent extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Color iconColor;

  const _AnimatedNotificationContent({
    required this.icon,
    required this.title,
    required this.color,
    required this.iconColor,
  });

  @override
  State<_AnimatedNotificationContent> createState() => _AnimatedNotificationContentState();
}

class _AnimatedNotificationContentState extends State<_AnimatedNotificationContent>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _iconController;
  late AnimationController _pulseController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconRotation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Slide and scale animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    // Icon bounce animation
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _iconRotation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    ));

    // Pulse animation for the glow effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _iconController.forward();
    });
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _iconController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateTimeFormat = DateFormat('MMM d, yyyy • h:mm a');

    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.color,
                widget.color.withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: widget.color.withOpacity(0.2),
                blurRadius: 40,
                offset: const Offset(0, 4),
                spreadRadius: -5,
              ),
            ],
          ),
          child: Row(
            children: [
              // Animated icon with glow
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: ScaleTransition(
                  scale: _iconRotation,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Text content
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateTimeFormat.format(now),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Decorative element
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
