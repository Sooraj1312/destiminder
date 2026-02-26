import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/history_service.dart';
import '../services/destination_service.dart';
import '../models/arrival_history.dart';
import '../models/destination.dart';
import '../widgets/emoji_icons.dart';  

class HistoryScreen extends StatefulWidget {
  final Destination? initialDestination;
  
  const HistoryScreen({super.key, this.initialDestination});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arrival History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Today'),
            Tab(text: 'Stats'),
          ],
        ),
        actions: [
          IconButton(
            icon: EmojiIcons.deleteHistory(),
            onPressed: _showClearDialog,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllHistory(),
          _buildTodayHistory(),
          _buildStats(),
        ],
      ),
    );
  }

  Widget _buildAllHistory() {
    return Consumer<HistoryService>(
      builder: (context, historyService, child) {
        final history = historyService.history;
        
        if (history.isEmpty) {
          return _buildEmptyState();
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final arrival = history[index];
            return _buildHistoryCard(arrival);
          },
        );
      },
    );
  }

  Widget _buildTodayHistory() {
    return Consumer<HistoryService>(
      builder: (context, historyService, child) {
        final today = historyService.todaysArrivals;
        
        if (today.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EmojiIcons.today(color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No arrivals today',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: today.length,
          itemBuilder: (context, index) {
            final arrival = today[index];
            return _buildHistoryCard(arrival);
          },
        );
      },
    );
  }

  Widget _buildStats() {
    return Consumer2<HistoryService, DestinationService>(
      builder: (context, historyService, destinationService, child) {
        final mostVisited = historyService.getMostVisited();
        final totalArrivals = historyService.getTotalArrivals();
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          EmojiIcons.history(size: 28, color: Colors.blue),
                          '$totalArrivals',
                          'Total Arrivals',
                          Colors.blue,
                        ),
                        _buildStatItem(
                          EmojiIcons.today(size: 28, color: Colors.green),
                          '${historyService.todaysArrivals.length}',
                          'Today',
                          Colors.green,
                        ),
                        _buildStatItem(
                          EmojiIcons.location(size: 28, color: Colors.orange),
                          '${destinationService.destinations.length}',
                          'Places',
                          Colors.orange,
                        ),

                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Most Visited Places
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Most Visited',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...mostVisited.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.value}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              'time${entry.value > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Per Destination Stats
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destination Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...destinationService.destinations.map((dest) {
                      final count = historyService.getArrivalsForDestination(dest.id);
                      final lastArrival = historyService.getLastArrival(dest.id);
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: dest.isActive ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dest.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (lastArrival != null)
                                    Text(
                                      'Last: ${DateFormat('MMM d, h:mm a').format(lastArrival)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(Widget icon, String value, String label, Color color) {
    return Column(
      children: [
        icon,
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(ArrivalHistory arrival) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: EmojiIcons.checkIn(color: Colors.green),
        ),
        title: Text(
          arrival.destinationName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(arrival.arrivalTime),
            ),
            Text(
              'at ${DateFormat('h:mm a').format(arrival.arrivalTime)}',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: EmojiIcons.moreVert(),
          onPressed: () {
            _showArrivalOptions(arrival);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmojiIcons.history(color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No arrival history yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your arrivals will appear here',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to delete all arrival history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final historyService = Provider.of<HistoryService>(
                context, 
                listen: false
              );
              await historyService.clearHistory();
              if (mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showArrivalOptions(ArrivalHistory arrival) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: EmojiIcons.deleteHistory(color: Colors.red),
              title: const Text('Delete this record'),
              onTap: () async {
                Navigator.pop(context);
                final historyService = Provider.of<HistoryService>(
                  context, 
                  listen: false
                );
                await historyService.deleteArrival(arrival.id);
              },
            ),
            ListTile(
              leading: EmojiIcons.share(),
              title: const Text('Share arrival'),
              onTap: () {
                Navigator.pop(context);
                // Share functionality
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}