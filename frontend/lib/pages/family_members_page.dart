import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:timeago/timeago.dart' as timeago;
import '../services/household_service_controller.dart';

class FamilyMembersPage extends StatefulWidget {
  final String householdId;

  const FamilyMembersPage({Key? key, required this.householdId}) : super(key: key);

  @override
  _FamilyMembersPageState createState() => _FamilyMembersPageState();
}

class _FamilyMembersPageState extends State<FamilyMembersPage> with SingleTickerProviderStateMixin {
  final HouseholdServiceController _controller = HouseholdServiceController();
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color accentColor = Color(0xFF4CAF50);
  final Color backgroundColor = Color(0xFFE2E6E0);
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _householdMembers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _userRole = 'member';
  bool _isOwner = false;
  bool _isRemovingMember = false;
  int? _removingMemberIndex;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  int _pageSize = 10;
  AnimationController? _fabController;
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _loadData();
    
    // Listen to scroll events to hide/show FAB
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        _showFloatingActionButton();
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        _hideFloatingActionButton();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabController?.dispose();
    super.dispose();
  }

  void _showFloatingActionButton() {
    if (!_showFab) {
      setState(() => _showFab = true);
      _fabController?.forward();
    }
  }

  void _hideFloatingActionButton() {
    if (_showFab) {
      setState(() => _showFab = false);
      _fabController?.reverse();
    }
  }

  Future<void> _loadData({bool loadMore = false}) async {
    if (loadMore && (!_hasMore || _isLoadingMore)) return;
    
    try {
      setState(() {
        if (loadMore) {
          _isLoadingMore = true;
        } else {
          _isLoading = true;
          _householdMembers = [];
          _lastDocument = null;
          _hasMore = true;
        }
      });

      // Get user role first
      final role = await _controller.getUserRole(widget.householdId);
      
      // Use getHouseholdMembers to load data from members subcollection
      final result = await _controller.getHouseholdMembersPaginated(
        widget.householdId, 
        limit: _pageSize, 
        startAfter: loadMore ? _lastDocument : null
      );
      
      setState(() {
        _userRole = role;
        _isOwner = role == 'creator';
        
        if (loadMore) {
          _householdMembers.addAll(result.members);
          _isLoadingMore = false;
        } else {
          _householdMembers = result.members;
          _isLoading = false;
        }
        
        _lastDocument = result.lastDocument;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      
      String errorMessage = 'Error loading household members: $e';
      bool isRetryable = false;
      
      if (e.toString().contains('Network') || e.toString().contains('socket')) {
        errorMessage = 'Network issue. Please check your connection.';
        isRetryable = true;
      } else if (e.toString().contains('permission') || e.toString().contains('access')) {
        errorMessage = 'You don\'t have permission to view household members.';
      }
      
      if (isRetryable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _loadData(loadMore: loadMore);
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Format role for better display
  String _formatRole(String role) {
    switch (role) {
      case 'creator':
        return 'Owner';
      case 'member':
        return 'Member';
      default:
        return role;
    }
  }

  // Format date using timeago for relative time
  String _formatDate(dynamic date) {
    if (date == null) return 'Not joined yet';
    
    try {
      if (date is Timestamp) {
        return timeago.format(date.toDate());
      }
      return date.toString();
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Remove a member with confirmation and loading state
  void _removeMember(int index) async {
    final member = _householdMembers[index];
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Remove Member"),
          content: Text("Are you sure you want to remove ${member['email'] ?? 'this member'} from the household?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Remove", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true) {
      setState(() {
        _isRemovingMember = true;
        _removingMemberIndex = index;
      });
      
      try {
        // Remove member from both collections
        await _controller.removeHouseholdMember(widget.householdId, member['userId']);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${member['email']} has been removed"),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the list
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to remove member: $e"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isRemovingMember = false;
          _removingMemberIndex = null;
        });
      }
    }
  }

  Widget _buildMemberCard(Map<String, dynamic> member, int index) {
    final bool isCreator = member['userRole'] == 'creator';
    final bool isRemovingThisMember = _isRemovingMember && _removingMemberIndex == index;
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        leading: CircleAvatar(
          backgroundColor: primaryColor.withOpacity(0.2),
          child: Icon(
            isCreator ? Icons.star : Icons.person,
            color: primaryColor,
          ),
        ),
        title: Text(
          member['email'] ?? 'Unknown User',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: ${_formatRole(member['userRole'] ?? 'member')}'),
            if (member['joinedAt'] != null)
              Text('Joined: ${_formatDate(member['joinedAt'])}'),
            if (member['lastSeen'] != null)
              Text('Last seen: ${_formatDate(member['lastSeen'])}'),
          ],
        ),
        trailing: _isOwner && !isCreator
            ? isRemovingThisMember
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _removeMember(index),
                  )
            : null,
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (_isLoadingMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_hasMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () => _loadData(loadMore: true),
            child: Text("Load More"),
          ),
        ),
      );
    }
    
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Household Members",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isOwner)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () => _loadData(),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            )
          : _householdMembers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.black38),
                      SizedBox(height: 16),
                      Text(
                        'No household members yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Members will appear here once they join',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (!_isLoadingMore && 
                        _hasMore && 
                        scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                      _loadData(loadMore: true);
                      return true;
                    }
                    return false;
                  },
                  child: RefreshIndicator(
                    onRefresh: () => _loadData(),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: _householdMembers.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _householdMembers.length) {
                          return _buildLoadMoreButton();
                        }
                        return _buildMemberCard(_householdMembers[index], index);
                      },
                    ),
                  ),
                ),
    );
  }
}