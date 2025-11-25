import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/pages/Dashboard/dashboard_page.dart';

// Enhanced Activity Item Widget
class EnhancedActivityItem extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textLight;
  final bool isPinned;

  const EnhancedActivityItem({
    Key? key,
    required this.activity,
    required this.onTap,
    required this.primaryColor,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textLight,
    this.isPinned = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timestamp = activity['timestamp'] as Timestamp;
    final time = timestamp.toDate().toLocal();
    final icon = _getActivityIcon(activity['type']);
    final color = _getActivityColor(activity['type']);

    // Extract user and item information
    final String fullName = activity['fullName'] ?? 'Unknown User';
    final String itemName = activity['itemName'] ?? '';
    final String profileImage = activity['profileImage'] ?? '';
    final String itemImage = activity['itemImage'] ?? '';
    final bool isImportant =
        activity['type'] == 'warning' || activity['type'] == 'delete';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: isPinned ? 4 : 2,
        borderRadius: BorderRadius.circular(20),
        color: surfaceColor,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPinned
                    ? color.withOpacity(0.3)
                    : color.withOpacity(0.1),
                width: isPinned ? 2 : 1,
              ),
              gradient: isImportant
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.05),
                        color.withOpacity(0.02),
                      ],
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Activity Type Icon
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.25), color.withOpacity(0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),

                SizedBox(width: 16),

                // User Avatar
                Stack(
                  children: [
                    if (profileImage.isNotEmpty)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(profileImage),
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: surfaceColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(Icons.check, size: 8, color: Colors.white),
                      ),
                    ),
                  ],
                ),

                SizedBox(width: 16),

                // Content Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Activity Message
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isImportant)
                            Container(
                              margin: EdgeInsets.only(right: 8, top: 2),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              activity['message'] ?? 'Activity',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // User info
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: primaryColor,
                            ),
                            SizedBox(width: 6),
                            Text(
                              fullName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (itemName.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.inventory_2_rounded,
                                  size: 12,
                                  color: primaryColor,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                itemName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Time and Action Section
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Time with context
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            textLight.withOpacity(0.1),
                            textLight.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: textLight,
                          ),
                          SizedBox(height: 2),
                          Text(
                            _formatTime(time),
                            style: TextStyle(
                              fontSize: 11,
                              color: textLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _getTimeContext(time),
                            style: TextStyle(
                              fontSize: 9,
                              color: textLight.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 8),

                    // Item Image
                    if (itemImage.isNotEmpty || itemName.isNotEmpty)
                      Stack(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: itemImage.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(itemImage),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: itemImage.isEmpty
                                  ? primaryColor.withOpacity(0.1)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: itemImage.isEmpty
                                ? Icon(
                                    Icons.inventory_2_rounded,
                                    size: 18,
                                    color: primaryColor,
                                  )
                                : null,
                          ),
                          if (isPinned)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: surfaceColor,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  size: 8,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getTimeContext(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activityDate = DateTime(date.year, date.month, date.day);

    if (activityDate == today) {
      return 'Today';
    } else if (activityDate == today.subtract(Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'add':
        return Icons.add_circle_rounded;
      case 'update':
        return Icons.edit_rounded;
      case 'delete':
        return Icons.delete_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'info':
        return Icons.info_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'add':
        return Color(0xFF10B981);
      case 'update':
        return Color(0xFF3B82F6);
      case 'delete':
        return Color(0xFFEF4444);
      case 'warning':
        return Color(0xFFF59E0B);
      case 'info':
        return Color(0xFF6B7280);
      default:
        return Color(0xFF6B7280);
    }
  }
}

// Enhanced Activity Detail Page
class ActivityDetailPage extends StatelessWidget {
  final Map<String, dynamic> activity;

  const ActivityDetailPage({Key? key, required this.activity})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timestamp = activity['timestamp'] as Timestamp;
    final time = timestamp.toDate().toLocal();
    final icon = _getActivityIcon(activity['type']);
    final color = _getActivityColor(activity['type']);
    final primaryColor = Color(0xFF2D5D7C);
    final surfaceColor = Color(0xFFFFFFFF);
    final textPrimary = Color(0xFF1E293B);
    final textSecondary = Color(0xFF64748B);

    // Extract user and item information
    final String fullName = activity['fullName'] ?? 'User';
    final String itemName = activity['itemName'] ?? 'No item';
    final String profileImage = activity['profileImage'] ?? '';
    final String itemImage = activity['itemImage'] ?? '';

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Activity Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_ios_rounded, size: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            _buildHeaderCard(icon, color, textPrimary, textSecondary, time),

            SizedBox(height: 24),

            // Activity Message Card
            _buildMessageCard(
              activity,
              primaryColor,
              textPrimary,
              textSecondary,
              surfaceColor,
            ),

            SizedBox(height: 20),

            // Participants Section
            _buildParticipantsSection(
              fullName,
              profileImage,
              itemName,
              itemImage,
              primaryColor,
              surfaceColor,
              textPrimary,
            ),

            SizedBox(height: 24),

            // Timeline Section
            _buildTimelineSection(
              time,
              primaryColor,
              surfaceColor,
              textPrimary,
              textSecondary,
            ),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    IconData icon,
    Color color,
    Color textPrimary,
    Color textSecondary,
    DateTime time,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 25,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.4), color.withOpacity(0.2)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _getActivityTypeLabel(activity['type']).toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  _formatFullDate(time),
                  style: TextStyle(
                    fontSize: 18,
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      _formatDetailedTime(time),
                      style: TextStyle(
                        fontSize: 15,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(
    Map<String, dynamic> activity,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    Color surfaceColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Activity Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFE2E8F0)),
            ),
            child: Text(
              activity['message'] ?? 'No message provided',
              style: TextStyle(
                fontSize: 16,
                color: textSecondary,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(
    String fullName,
    String profileImage,
    String itemName,
    String itemImage,
    Color primaryColor,
    Color surfaceColor,
    Color textPrimary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_alt_rounded, color: primaryColor, size: 22),
            SizedBox(width: 8),
            Text(
              'Participants',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _buildEnhancedParticipantCard(
          'User',
          fullName,
          profileImage,
          Icons.person_rounded,
          primaryColor,
          surfaceColor,
        ),
        if (itemName != 'No item') ...[
          SizedBox(height: 12),
          _buildEnhancedParticipantCard(
            'Item',
            itemName,
            itemImage,
            Icons.inventory_2_rounded,
            primaryColor,
            surfaceColor,
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineSection(
    DateTime time,
    Color primaryColor,
    Color surfaceColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timeline_rounded, color: primaryColor, size: 22),
            SizedBox(width: 8),
            Text(
              'Activity Timeline',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 25,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildEnhancedTimelineItem(
                Icons.access_time_rounded,
                'Activity Time',
                _formatDetailedTime(time),
                'When this activity occurred',
                primaryColor,
              ),
              SizedBox(height: 20),
              _buildEnhancedTimelineItem(
                Icons.calendar_today_rounded,
                'Activity Date',
                _formatFullDate(time),
                'Date of the activity',
                primaryColor,
              ),
              SizedBox(height: 20),
              _buildEnhancedTimelineItem(
                Icons.language_rounded,
                'Timezone',
                'Local Time',
                'Your device timezone',
                primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedParticipantCard(
    String title,
    String name,
    String imageUrl,
    IconData icon,
    Color color,
    Color surfaceColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            // Enhanced Avatar
            if (imageUrl.isNotEmpty)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: color.withOpacity(0.2), width: 2),
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: color.withOpacity(0.2), width: 2),
                ),
                child: Icon(icon, color: color, size: 28),
              ),

            SizedBox(width: 20),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedTimelineItem(
    IconData icon,
    String title,
    String value,
    String description,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatFullDate(DateTime date) {
    return '${_getWeekday(date.weekday)}, ${date.day} ${_getMonth(date.month)} ${date.year}';
  }

  String _formatDetailedTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _getMonth(int month) {
    switch (month) {
      case 1:
        return 'January';
      case 2:
        return 'February';
      case 3:
        return 'March';
      case 4:
        return 'April';
      case 5:
        return 'May';
      case 6:
        return 'June';
      case 7:
        return 'July';
      case 8:
        return 'August';
      case 9:
        return 'September';
      case 10:
        return 'October';
      case 11:
        return 'November';
      case 12:
        return 'December';
      default:
        return '';
    }
  }

  String _getActivityTypeLabel(String type) {
    switch (type) {
      case 'add':
        return 'Item Added';
      case 'update':
        return 'Item Updated';
      case 'delete':
        return 'Item Deleted';
      case 'warning':
        return 'Stock Alert';
      case 'info':
        return 'Information';
      default:
        return 'Activity';
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'add':
        return Icons.add_circle_rounded;
      case 'update':
        return Icons.edit_rounded;
      case 'delete':
        return Icons.delete_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'info':
        return Icons.info_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'add':
        return Color(0xFF10B981);
      case 'update':
        return Color(0xFF3B82F6);
      case 'delete':
        return Color(0xFFEF4444);
      case 'warning':
        return Color(0xFFF59E0B);
      case 'info':
        return Color(0xFF6B7280);
      default:
        return Color(0xFF6B7280);
    }
  }
}

// Main Activity Log Page
class ActivityLogPage extends StatefulWidget {
  final String householdId;
  final String householdName;

  const ActivityLogPage({
    Key? key,
    required this.householdId,
    required this.householdName,
  }) : super(key: key);

  @override
  _ActivityLogPageState createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage>
    with SingleTickerProviderStateMixin {
  final DashboardService _dashboardService = DashboardService();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _allActivities = [];
  final List<Map<String, dynamic>> _filteredActivities = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _limit = 15;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  bool _showFilters = false;

  final Color _primaryColor = Color(0xFF2D5D7C);
  final Color _surfaceColor = Color(0xFFFFFFFF);
  final Color _textPrimary = Color(0xFF1E293B);
  final Color _textSecondary = Color(0xFF64748B);
  final Color _textLight = Color(0xFF94A3B8);

  late AnimationController _animationController;
  late Animation<double> _filterAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _filterAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadInitialActivities();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _hasMore &&
        !_isLoading) {
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
          _filteredActivities.clear();
          _filteredActivities.addAll(_applyFilters(_allActivities));
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
          _filteredActivities.clear();
          _filteredActivities.addAll(_applyFilters(_allActivities));
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

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> activities,
  ) {
    List<Map<String, dynamic>> filtered = activities;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((activity) {
        final message = activity['message']?.toString().toLowerCase() ?? '';
        final itemName = activity['itemName']?.toString().toLowerCase() ?? '';
        final fullName = activity['fullName']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        return message.contains(query) ||
            itemName.contains(query) ||
            fullName.contains(query);
      }).toList();
    }

    // Apply type filter
    if (_selectedFilter != 'all') {
      filtered = filtered
          .where((activity) => activity['type'] == _selectedFilter)
          .toList();
    }

    return filtered;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredActivities.clear();
      _filteredActivities.addAll(_applyFilters(_allActivities));
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _filteredActivities.clear();
      _filteredActivities.addAll(_applyFilters(_allActivities));
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
      if (_showFilters) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _refreshActivities() async {
    await _loadInitialActivities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Log',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              widget.householdName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.refresh_rounded, size: 20),
            ),
            onPressed: _refreshActivities,
            tooltip: 'Refresh Activities',
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: _textLight, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search activities...',
                            hintStyle: TextStyle(color: _textLight),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: TextStyle(fontSize: 15, color: _textPrimary),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: _textLight,
                          ),
                          onPressed: () => _onSearchChanged(''),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 12),

                // Filter Toggle
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_filteredActivities.length} activities found',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleFilters,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_list_rounded,
                              size: 16,
                              color: _primaryColor,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              _showFilters
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 16,
                              color: _primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Animated Filter Options
                SizeTransition(
                  sizeFactor: _filterAnimation,
                  child: Column(
                    children: [
                      SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFilterChip('All', 'all'),
                          _buildFilterChip('Added', 'add'),
                          _buildFilterChip('Updated', 'update'),
                          _buildFilterChip('Deleted', 'delete'),
                          _buildFilterChip('Alerts', 'warning'),
                          _buildFilterChip('Info', 'info'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Activities List
          Expanded(
            child: _filteredActivities.isEmpty && !_isLoading
                ? _buildEnhancedEmptyState()
                : RefreshIndicator(
                    onRefresh: _refreshActivities,
                    color: _primaryColor,
                    backgroundColor: _surfaceColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(20),
                      itemCount:
                          _filteredActivities.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _filteredActivities.length) {
                          return _buildEnhancedLoadMoreIndicator();
                        }

                        final activity = _filteredActivities[index];
                        final isPinned = activity['type'] == 'warning';

                        return EnhancedActivityItem(
                          activity: activity,
                          onTap: () => _showActivityDetails(activity),
                          primaryColor: _primaryColor,
                          surfaceColor: _surfaceColor,
                          textPrimary: _textPrimary,
                          textSecondary: _textSecondary,
                          textLight: _textLight,
                          isPinned: isPinned,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : _primaryColor,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) => _onFilterChanged(selected ? value : 'all'),
      backgroundColor: _primaryColor.withOpacity(0.1),
      selectedColor: _primaryColor,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? _primaryColor : _primaryColor.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildEnhancedLoadMoreIndicator() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: _isLoading
            ? Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(_primaryColor),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Loading more activities...',
                    style: TextStyle(
                      fontSize: 13,
                      color: _textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : _hasMore
            ? ElevatedButton.icon(
                onPressed: _loadMoreActivities,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
                icon: Icon(Icons.autorenew_rounded, size: 18),
                label: Text(
                  'Load More Activities',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              )
            : Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  'End',
                  style: TextStyle(
                    fontSize: 13,
                    color: _textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEnhancedEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 70,
                color: _primaryColor.withOpacity(0.3),
              ),
            ),
            SizedBox(height: 32),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No matching activities'
                  : 'No Activities Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'No activities found for "${_searchQuery}". Try different keywords or clear your search.'
                    : 'Activities will appear here when you add, update, or delete items from your inventory.',
                style: TextStyle(fontSize: 15, color: _textLight, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 32),
            if (_searchQuery.isNotEmpty)
              ElevatedButton(
                onPressed: () => _onSearchChanged(''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Clear Search',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _refreshActivities,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
                icon: Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Refresh Activities',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showActivityDetails(Map<String, dynamic> activity) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ActivityDetailPage(activity: activity),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: Duration(milliseconds: 400),
      ),
    );
  }
}
