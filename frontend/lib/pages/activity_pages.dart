import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/pages/dashboard_page.dart';

// Activity Detail Page
class ActivityDetailPage extends StatelessWidget {
  final Map<String, dynamic> activity;

  const ActivityDetailPage({Key? key, required this.activity}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timestamp = activity['timestamp'] as Timestamp;
    final time = timestamp.toDate();
    final icon = _getActivityIcon(activity['type']);
    final color = _getActivityColor(activity['type']);
    final primaryColor = Color(0xFF2D5D7C);
    final surfaceColor = Color(0xFFFFFFFF);
    final textPrimary = Color(0xFF1E293B);
    final textSecondary = Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Details'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getActivityTypeLabel(activity['type']),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatFullDate(time),
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),
            
            // Activity Message
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    activity['message'] ?? 'No message',
                    style: TextStyle(
                      fontSize: 15,
                      color: textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // Details Grid
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                _buildDetailCard(
                  'User',
                  activity['userName'] ?? 'Unknown',
                  Icons.person_rounded,
                  primaryColor,
                  surfaceColor,
                ),
                _buildDetailCard(
                  'Time',
                  _formatTime(time),
                  Icons.access_time_rounded,
                  primaryColor,
                  surfaceColor,
                ),
                if (activity['itemName'] != null)
                  _buildDetailCard(
                    'Item',
                    activity['itemName']!,
                    Icons.inventory_2_rounded,
                    primaryColor,
                    surfaceColor,
                  ),
                _buildDetailCard(
                  'Date',
                  _formatDate(time),
                  Icons.calendar_today_rounded,
                  primaryColor,
                  surfaceColor,
                ),
              ],
            ),
            
            // Value Changes (if available)
            if (activity['oldValue'] != null && activity['newValue'] != null) ...[
              SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Value Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Before',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '${activity['oldValue']}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward_rounded, color: primaryColor),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'After',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '${activity['newValue']}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon, Color color, Color surfaceColor) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatFullDate(DateTime date) {
    return '${_getWeekday(date.weekday)}, ${date.day} ${_getMonth(date.month)} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour < 12 ? 'AM' : 'PM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  String _getMonth(int month) {
    switch (month) {
      case 1: return 'January';
      case 2: return 'February';
      case 3: return 'March';
      case 4: return 'April';
      case 5: return 'May';
      case 6: return 'June';
      case 7: return 'July';
      case 8: return 'August';
      case 9: return 'September';
      case 10: return 'October';
      case 11: return 'November';
      case 12: return 'December';
      default: return '';
    }
  }

  String _getActivityTypeLabel(String type) {
    switch (type) {
      case 'add': return 'Item Added';
      case 'update': return 'Item Updated';
      case 'delete': return 'Item Deleted';
      case 'warning': return 'Stock Alert';
      case 'info': return 'Information';
      default: return 'Activity';
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'add': return Icons.add_circle_rounded;
      case 'update': return Icons.edit_rounded;
      case 'delete': return Icons.delete_rounded;
      case 'warning': return Icons.warning_amber_rounded;
      case 'info': return Icons.info_rounded;
      default: return Icons.info_rounded;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'add': return Color(0xFF10B981);
      case 'update': return Color(0xFF3B82F6);
      case 'delete': return Color(0xFFEF4444);
      case 'warning': return Color(0xFFF59E0B);
      case 'info': return Color(0xFF6B7280);
      default: return Color(0xFF6B7280);
    }
  }
}

// Activity Log Page with Infinite Scroll
class ActivityLogPage extends StatefulWidget {
  final String householdId;
  final String householdName;

  const ActivityLogPage({Key? key, required this.householdId, required this.householdName}) : super(key: key);

  @override
  _ActivityLogPageState createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  final DashboardService _dashboardService = DashboardService();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _allActivities = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _limit = 15;

  final Color _primaryColor = Color(0xFF2D5D7C);
  final Color _surfaceColor = Color(0xFFFFFFFF);
  final Color _textPrimary = Color(0xFF1E293B);
  final Color _textSecondary = Color(0xFF64748B);
  final Color _textLight = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _loadInitialActivities();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasMore && !_isLoading) {
      _loadMoreActivities();
    }
  }

  Future<void> _loadInitialActivities() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final activities = await _dashboardService.getActivitiesPaginated(
        widget.householdId,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _allActivities.clear();
          _allActivities.addAll(activities['activities']);
          _lastDocument = activities['lastDocument'];
          _hasMore = activities['hasMore'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreActivities() async {
    if (!_hasMore || _isLoading) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final activities = await _dashboardService.getActivitiesPaginated(
        widget.householdId,
        limit: _limit,
        startAfter: _lastDocument,
      );

      if (mounted) {
        setState(() {
          _allActivities.addAll(activities['activities']);
          _lastDocument = activities['lastDocument'];
          _hasMore = activities['hasMore'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshActivities() async {
    await _loadInitialActivities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Log - ${widget.householdName}'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _refreshActivities,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshActivities,
        color: _primaryColor,
        backgroundColor: _surfaceColor,
        child: Column(
          children: [
            // Stats Summary
            if (_allActivities.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _primaryColor.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total', _allActivities.length, Icons.analytics_rounded),
                    _buildStatItem('Today', _getTodayActivities(), Icons.today_rounded),
                    _buildStatItem('This Week', _getThisWeekActivities(), Icons.calendar_view_week_rounded),
                  ],
                ),
              ),
            
            // Activities List
            Expanded(
              child: _allActivities.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16),
                      itemCount: _allActivities.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _allActivities.length) {
                          return _buildLoadMoreIndicator();
                        }
                        
                        final activity = _allActivities[index];
                        return EnhancedActivityItem(
                          activity: activity,
                          onTap: () => _showActivityDetails(activity),
                          primaryColor: _primaryColor,
                          surfaceColor: _surfaceColor,
                          textPrimary: _textPrimary,
                          textSecondary: _textSecondary,
                          textLight: _textLight,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: _primaryColor),
        ),
        SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _textSecondary,
          ),
        ),
      ],
    );
  }

  int _getTodayActivities() {
    final now = DateTime.now();
    return _allActivities.where((activity) {
      final timestamp = activity['timestamp'] as Timestamp;
      final activityDate = timestamp.toDate();
      return activityDate.year == now.year &&
             activityDate.month == now.month &&
             activityDate.day == now.day;
    }).length;
  }

  int _getThisWeekActivities() {
    final now = DateTime.now();
    final weekAgo = now.subtract(Duration(days: 7));
    return _allActivities.where((activity) {
      final timestamp = activity['timestamp'] as Timestamp;
      final activityDate = timestamp.toDate();
      return activityDate.isAfter(weekAgo);
    }).length;
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _hasMore
                ? TextButton(
                    onPressed: _loadMoreActivities,
                    child: Text('Load More Activities'),
                  )
                : Container(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _textLight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 50,
                color: _textLight.withOpacity(0.4),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'No activities yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Activities will appear here when you add, update, or delete items from your inventory',
              style: TextStyle(
                fontSize: 14,
                color: _textLight,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showActivityDetails(Map<String, dynamic> activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailPage(activity: activity),
      ),
    );
  }
}