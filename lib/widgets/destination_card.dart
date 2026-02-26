import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import '../models/destination.dart';
import '../widgets/emoji_icons.dart';

class DestinationCard extends StatelessWidget {
  final Destination destination;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive; 
  final double? liveDistance; 

  const DestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
    required this.onDelete,
    required this.onToggleActive,
    this.liveDistance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SwipeActionCell(
        key: ValueKey(destination.id),
        trailingActions: [
          SwipeAction(
            onTap: (CompletionHandler handler) async {
              await handler(true);
              onDelete();
            },
            color: Colors.red,
            icon: EmojiIcons.delete(color: Colors.white),
            widthSpace: 80,
          ),
        ],
        child: Container(
          decoration: BoxDecoration(
            gradient: destination.isActive
                ? LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.1),
                      theme.colorScheme.secondary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: destination.isActive
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  )
                : Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon with gradient background
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: destination.isActive
                              ? [theme.colorScheme.primary, theme.colorScheme.secondary]
                              : [Colors.grey.shade400, Colors.grey.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (destination.isActive 
                                ? theme.colorScheme.primary 
                                : Colors.grey).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: destination.isActive 
                            ? EmojiIcons.activeDestination(color: Colors.white)
                            : EmojiIcons.inactiveDestination(color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    
                    // Destination info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  destination.displayName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // NEW - Active switch
                              Switch(
                                value: destination.isActive,
                                onChanged: onToggleActive,
                                activeColor: theme.colorScheme.primary,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              EmojiIcons.address(color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  destination.address,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              EmojiIcons.radiusIndicator(color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${destination.radius}m radius',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const Spacer(),
                              if (destination.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'ACTIVE',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          if (liveDistance != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                EmojiIcons.distanceWalk(color: liveDistance! < 100 ? Colors.green : Colors.blue),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    liveDistance! < 1000 
                                        ? '${liveDistance!.toStringAsFixed(0)}m away'
                                        : '${(liveDistance!/1000).toStringAsFixed(1)}km away',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: liveDistance! < 100 ? Colors.green : Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (liveDistance! < destination.radius)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'ARRIVING',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
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