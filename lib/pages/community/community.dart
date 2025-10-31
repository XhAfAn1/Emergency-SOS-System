import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:rxdart/rxdart.dart';
import '../../Class Models/social model.dart';
import '../../Class Models/user.dart';
import 'dart:async';
import '../homepage/drawer.dart';

enum SortBy { hot, newest, top}
enum TimeFilter { hour, day, week, month, year, all }

class SocialScreen extends StatefulWidget {
  final UserModel currentUser;
  final PostModel? temppost;

  const SocialScreen({Key? key, required this.currentUser, this.temppost}) : super(key: key);

  @override
  _SocialScreenState createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  final FocusNode _postFocusNode = FocusNode();
  SortBy _sortBy = SortBy.hot;
  TimeFilter _timeFilter = TimeFilter.all;
  bool _showFilters = false;
  bool _isPostExpanded = false;

  // Real-time data streams
  late StreamSubscription<List<QuerySnapshot>> _postsSubscription;
  List<PostModel> _allPosts = [];
  bool _isLoading = true;

  // White theme color palette
  static const Color primaryRed = Color(0xFFEF4444);
  static const Color primaryBlue = Color(0xFF1F2937);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMedium = Color(0xFF374151);
  static const Color textLight = Color(0xFF6B7280);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color chipBackground = Color(0xFFF1F5F9);
  static const Color iconColor = Color(0xFF9CA3AF);
  static const Color upvoteColor = Color(0xFFFF4500);
  static const Color downvoteColor = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    if (widget.temppost != null) {
      _firestore.collection('social').doc('temp_post').set(widget.temppost!.toJson());
    }
    WidgetsBinding.instance.addObserver(this);
    _initializeRealTimeListeners();

    _postFocusNode.addListener(() {
      setState(() {
        _isPostExpanded = _postFocusNode.hasFocus || _postController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _postsSubscription.cancel();
    _postController.dispose();
    _editController.dispose();
    _postFocusNode.dispose();
    super.dispose();
  }

  void _initializeRealTimeListeners() {
    _postsSubscription = _getCombinedPostsStream().listen(
          (snapshots) {
        if (mounted) {
          _updatePostsFromSnapshots(snapshots);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading posts: $error'),
              backgroundColor: primaryRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
    );
  }

  void _updatePostsFromSnapshots(List<QuerySnapshot> snapshots) {
    List<PostModel> newPosts = [];

    // Process temp posts (first snapshot)
    for (var doc in snapshots[0].docs) {
      try {
        final post = PostModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
        newPosts.add(post);
      } catch (e) {
        debugPrint('Error parsing temp post: $e');
      }
    }

    // Process regular posts (second snapshot)
    for (var doc in snapshots[1].docs) {
      try {
        final post = PostModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
        newPosts.add(post);
      } catch (e) {
        debugPrint('Error parsing regular post: $e');
      }
    }

    setState(() {
      _allPosts = newPosts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(currentUser: widget.currentUser,activePage: 2,),
      backgroundColor: backgroundLight,
      body: RefreshIndicator(
        backgroundColor: Colors.white,

        color: Colors.black,
        strokeWidth:2,
        onRefresh: ()async{
          _postsSubscription.cancel();
          setState(() {
            _isLoading = true;
          });
          _initializeRealTimeListeners();

        },
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            if (_showFilters)
              SliverToBoxAdapter(child: _buildFiltersSection()),
            SliverToBoxAdapter(child: _buildInlineCreatePostSection()),
            _buildPostsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      collapsedHeight: 70,
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12.0,top: 10,right: 0),
        child: Builder(
          builder: (context) {
            return GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Color(0xFF1F2937),
                  size: 24,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: chipBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(
              _showFilters ? Icons.tune : Icons.tune_outlined,
              color: textLight,
              size: 20,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ),
        SizedBox(width: 8,)
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Community Feed',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cardBackground,
                backgroundLight,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: textDark.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sort by',
            style: TextStyle(
              color: textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _buildSortChips(),
          if (_sortBy == SortBy.top) ...[
            const SizedBox(height: 20),
            const Text(
              'Timeframe',
              style: TextStyle(
                color: textDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimeChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildSortChips() {
    final sortOptions = [
      ('Hot', SortBy.hot),
      ('New', SortBy.newest),
      ('Top', SortBy.top),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: sortOptions
          .map((option) => _buildChip(
        option.$1,
        _sortBy == option.$2,
            () => setState(() => _sortBy = option.$2),
        primaryBlue,
      ))
          .toList(),
    );
  }

  Widget _buildTimeChips() {
    final timeOptions = [
      ('Hour', TimeFilter.hour),
      ('Day', TimeFilter.day),
      ('Week', TimeFilter.week),
      ('Month', TimeFilter.month),
      ('Year', TimeFilter.year),
      ('All', TimeFilter.all),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: timeOptions
          .map((option) => _buildChip(
        option.$1,
        _timeFilter == option.$2,
            () => setState(() => _timeFilter = option.$2),
        primaryRed,
      ))
          .toList(),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap, Color activeColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : chipBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : borderColor,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : textMedium,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInlineCreatePostSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: textDark.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryBlue.withOpacity(0.1),
                backgroundImage: widget.currentUser.profileImageUrl.isNotEmpty
                    ? NetworkImage(widget.currentUser.profileImageUrl)
                    : null,
                child: widget.currentUser.profileImageUrl.isEmpty
                    ? Icon(Icons.person, color: primaryBlue, size: 24)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _postController,
                  focusNode: _postFocusNode,
                  maxLines: _isPostExpanded ? 4 : 1,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts...',
                    hintStyle: const TextStyle(
                      color: textLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: primaryBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: backgroundLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

            ],
          ),
          if (_isPostExpanded) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 8),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _postController.clear();
                    _postFocusNode.unfocus();
                    setState(() {
                      _isPostExpanded = false;
                    });
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _postController.text.trim().isNotEmpty ? _createPost : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Post',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildPostsList() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryBlue),
              SizedBox(height: 16),
              Text(
                'Loading posts...',
                style: TextStyle(color: textLight, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_allPosts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: chipBackground,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: HugeIcon(
                  icon:HugeIcons.strokeRoundedUserGroup03,
                  size: 60,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'No posts yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Be the first to share your thoughts!',
                style: TextStyle(
                  fontSize: 16,
                  color: textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tempPosts = _allPosts.where((post) => post.temp == true).toList();
    var regularPosts = _allPosts.where((post) => post.temp != true).toList();

    regularPosts = _applyTimeFilter(regularPosts);
    regularPosts = _applySorting(regularPosts);

    final finalPosts = [...tempPosts, ...regularPosts];

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: _buildPostCard(finalPosts[index]),
        ),
        childCount: finalPosts.length,
      ),
    );
  }

  Stream<List<QuerySnapshot>> _getCombinedPostsStream() {
    final tempStream = _firestore
        .collection('social')
        .where('temp', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();

    final regularStream = _firestore
        .collection('social')
        .where('temp', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Rx.combineLatest2(
      tempStream,
      regularStream,
          (QuerySnapshot a, QuerySnapshot b) => [a, b],
    );
  }

  Widget _buildPostCard(PostModel post) {
    final isUpvoted = post.upvotes.contains(widget.currentUser.id);
    final upvoteCount = post.upvotes.length;
    final isOwner = post.userId == widget.currentUser.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: post.temp ? primaryRed.withOpacity(0.05) : cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: post.temp ? primaryRed.withOpacity(0.2) : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: textDark.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildPostMetadata(post)),
                if (isOwner) _buildPostMenu(post),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              post.content,
              style: const TextStyle(
                fontSize: 16,
                color: textDark,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),

            _buildBottomActionBar(post, isUpvoted, upvoteCount),
          ],
        ),
      ),
    );
  }

  Widget _buildPostMetadata(PostModel post) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: HugeIcon(icon:HugeIcons.strokeRoundedUserGroup03, color: Colors.black, size: 18),
        ),
        const SizedBox(width: 8),
        const Text(
          'r/ResQunity',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
        Flexible(
          child: Text(
            ' • Posted by u/${post.userName} • ${_formatDateTime(post.createdAt)}',
            style: const TextStyle(
              color: textLight,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPostMenu(PostModel post) {
    return PopupMenuButton<String>(
      color: Colors.white,
      icon: const Icon(Icons.more_horiz_rounded, color: textLight, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, color: textMedium, size: 18),
              const SizedBox(width: 12),
              const Text('Edit Post', style: TextStyle(color: textMedium)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, color: primaryRed, size: 18),
              const SizedBox(width: 12),
              const Text('Delete Post', style: TextStyle(color: primaryRed)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'edit') {
          _showEditPostDialog(post);
        } else if (value == 'delete') {
          _showDeleteConfirmation(post);
        }
      },
    );
  }

  Widget _buildBottomActionBar(PostModel post, bool isUpvoted, int upvoteCount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: chipBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _toggleUpvote(post.id, isUpvoted),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: isUpvoted ? upvoteColor : textLight,
                      size: 20,
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _formatVoteCount(upvoteCount),
                    style: TextStyle(
                      color: isUpvoted ? upvoteColor : textMedium,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () => _toggleDownvote(post.id),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: textLight,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          GestureDetector(
            onTap: () => _showCommentsDialog(post),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: chipBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mode_comment_outlined, color: textLight, size: 18),
                  const SizedBox(width: 6),
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('social')
                        .doc(post.id)
                        .collection('comments')
                        .snapshots(),
                    builder: (context, snapshot) {
                      int commentCount = 0;
                      if (snapshot.hasData) {
                        commentCount = snapshot.data!.docs.length;
                      }
                      return Text(
                        commentCount.toString(),
                        style: const TextStyle(
                          color: textMedium,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showEditPostDialog(PostModel post) {
    _editController.text = post.content;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    const Text(
                      'Edit Post',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _editPost(post);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'SAVE',
                        style: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: borderColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    controller: _editController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Edit your thoughts...',
                      hintStyle: const TextStyle(
                        color: textLight,
                        fontWeight: FontWeight.w500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryBlue, width: 2),
                      ),
                      filled: true,
                      fillColor: backgroundLight,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Post',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this post? This will also delete all comments and cannot be undone.',
          style: TextStyle(color: textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: textLight),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePostWithComments(post);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: primaryRed, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  List<PostModel> _applyTimeFilter(List<PostModel> posts) {
    if (_timeFilter == TimeFilter.all) return posts;
    final now = DateTime.now();
    DateTime filterDate;
    switch (_timeFilter) {
      case TimeFilter.hour:
        filterDate = now.subtract(const Duration(hours: 1));
        break;
      case TimeFilter.day:
        filterDate = now.subtract(const Duration(days: 1));
        break;
      case TimeFilter.week:
        filterDate = now.subtract(const Duration(days: 7));
        break;
      case TimeFilter.month:
        filterDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case TimeFilter.year:
        filterDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        return posts;
    }
    return posts.where((post) => post.createdAt.isAfter(filterDate)).toList();
  }

  List<PostModel> _applySorting(List<PostModel> posts) {
    switch (_sortBy) {
      case SortBy.hot:
        posts.sort((a, b) {
          final aScore = a.upvotes.length / (DateTime.now().difference(a.createdAt).inHours + 1);
          final bScore = b.upvotes.length / (DateTime.now().difference(b.createdAt).inHours + 1);
          return bScore.compareTo(aScore);
        });
        break;
      case SortBy.newest:
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortBy.top:
        posts.sort((a, b) => b.upvotes.length.compareTo(a.upvotes.length));
        break;
    }
    return posts;
  }

  String _formatVoteCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  String _formatDateTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty) return;
    try {
      final post = PostModel(
        id: '',
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        userProfileImage: widget.currentUser.profileImageUrl,
        content: _postController.text.trim(),
        createdAt: DateTime.now(),
        upvotes: [],
        downvotes: [],
        commentCount: 0,
        temp: false,
      );
      final postData = post.toJson();
      postData['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('social').add(postData);
      _postController.clear();
      _postFocusNode.unfocus();
      setState(() {
        _isPostExpanded = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post created successfully!'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _editPost(PostModel post) async {
    if (_editController.text.trim().isEmpty) return;
    try {
      await _firestore.collection('social').doc(post.id).update({
        'content': _editController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _editController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post updated successfully!'),
            backgroundColor: primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating post: $e'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _deletePostWithComments(PostModel post) async {
    try {
      WriteBatch batch = _firestore.batch();

      final commentsSnapshot = await _firestore
          .collection('social')
          .doc(post.id)
          .collection('comments')
          .get();

      for (var commentDoc in commentsSnapshot.docs) {
        batch.delete(commentDoc.reference);
      }

      batch.delete(_firestore.collection('social').doc(post.id));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post and all comments deleted successfully!'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting post: $e'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _toggleUpvote(String postId, bool isCurrentlyUpvoted) async {
    try {
      final postRef = _firestore.collection('social').doc(postId);
      if (isCurrentlyUpvoted) {
        await postRef.update({'upvotes': FieldValue.arrayRemove([widget.currentUser.id])});
      } else {
        await postRef.update({'upvotes': FieldValue.arrayUnion([widget.currentUser.id])});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating upvote: $e'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _toggleDownvote(String postId) async {
    try {
      // Placeholder for downvote functionality
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating downvote: $e'),
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showCommentsDialog(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RedditStyleCommentsBottomSheet(post: post, currentUser: widget.currentUser),
    );
  }
}

// Reddit-Style Comments Bottom Sheet with keyboard awareness
class RedditStyleCommentsBottomSheet extends StatefulWidget {
  final PostModel post;
  final UserModel currentUser;

  const RedditStyleCommentsBottomSheet({Key? key, required this.post, required this.currentUser}) : super(key: key);

  @override
  _RedditStyleCommentsBottomSheetState createState() => _RedditStyleCommentsBottomSheetState();
}

class _RedditStyleCommentsBottomSheetState extends State<RedditStyleCommentsBottomSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _replyingToCommentId;
  String? _replyingToUserName;

  // White theme colors
  static const Color primaryRed = Color(0xFFEF4444);
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMedium = Color(0xFF374151);
  static const Color textLight = Color(0xFF6B7280);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color cardBackground = Colors.white;
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color chipBackground = Color(0xFFF1F5F9);
  static const Color iconColor = Color(0xFF9CA3AF);
  static const Color upvoteColor = Color(0xFFFF4500);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildHeader(),
              const Divider(height: 1, color: borderColor),
              Expanded(child: _buildRedditStyleCommentsList(scrollController)),
              _buildKeyboardAwareCommentInput(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          const Text(
            'Comments',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const Spacer(),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('social')
                .doc(widget.post.id)
                .collection('comments')
                .snapshots(),
            builder: (context, snapshot) {
              int commentCount = 0;
              if (snapshot.hasData) {
                commentCount = snapshot.data!.docs.length;
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$commentCount',
                  style: const TextStyle(
                    color: textMedium,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: textLight, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildRedditStyleCommentsList(ScrollController scrollController) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('social')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: primaryRed),
                SizedBox(height: 16),
                Text(
                  'Loading comments...',
                  style: TextStyle(color: textLight, fontSize: 16),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: primaryRed, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading comments: ${snapshot.error}',
                  style: const TextStyle(color: textMedium, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyCommentsState();
        }

        List<CommentModel> comments = snapshot.data!.docs
            .map((doc) {
          try {
            return CommentModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
          } catch (e) {
            debugPrint('Error parsing comment: $e');
            return null;
          }
        })
            .where((comment) => comment != null)
            .cast<CommentModel>()
            .toList();

        List<CommentModel> parentComments = comments.where((c) => c.parentCommentId == null).toList();
        Map<String, List<CommentModel>> repliesMap = {};
        for (var comment in comments.where((c) => c.parentCommentId != null)) {
          repliesMap.putIfAbsent(comment.parentCommentId!, () => []).add(comment);
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: parentComments.length,
          itemBuilder: (context, index) {
            final comment = parentComments[index];
            final replies = repliesMap[comment.id] ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRedditStyleCommentCard(comment, 0, index == 0),
                ...replies.map((reply) => _buildRedditStyleCommentCard(reply, 1, false)),
                if (index < parentComments.length - 1) const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRedditStyleCommentCard(CommentModel comment, int depth, bool isTopComment) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('social')
          .doc(widget.post.id)
          .collection('comments')
          .doc(comment.id)
          .snapshots(),
      builder: (context, snapshot) {
        CommentModel currentComment = comment;
        if (snapshot.hasData && snapshot.data!.exists) {
          try {
            currentComment = CommentModel.fromJson(
              snapshot.data!.data() as Map<String, dynamic>,
              snapshot.data!.id,
            );
          } catch (e) {
            debugPrint('Error parsing real-time comment: $e');
          }
        }

        final isUpvoted = currentComment.upvotes.contains(widget.currentUser.id);

        return Container(
          margin: EdgeInsets.only(
            left: depth * 20.0,
            bottom: 12.0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Avatar and thread line
              Column(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:Color(0xFF1F2937).withOpacity(0.1),
                    backgroundImage: currentComment.userProfileImage.isNotEmpty
                        ? NetworkImage(currentComment.userProfileImage)
                        : null,
                    child: currentComment.userProfileImage.isEmpty
                        ? Icon(Icons.person, color: Color(0xFF1F2937), size: 18)
                        : null,
                  ),
                  if (depth == 0)
                    Container(
                      width: 2,
                      height: 40,
                      color: borderColor.withOpacity(0.3),
                      margin: const EdgeInsets.only(top: 8),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Right side - Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with username, badge, and timestamp
                    Row(
                      children: [
                        Text(
                          currentComment.userName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                        if (isTopComment && depth == 0) ...[
                          const SizedBox(width: 8),

                        ],
                        const SizedBox(width: 8),
                        Text(
                          '• ${_formatDateTime(currentComment.createdAt)}',
                          style: const TextStyle(
                            color: textLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (currentComment.createdAt != currentComment.createdAt) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '• Edited',
                            style: TextStyle(
                              color: textLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Comment content
                    Text(
                      currentComment.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: textDark,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action buttons row (Reddit style)
                    Row(
                      children: [
                        // Upvote button
                        GestureDetector(
                          onTap: () => _toggleCommentUpvote(currentComment.id, isUpvoted),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: isUpvoted ? upvoteColor : iconColor,
                              size: 20,
                            ),
                          ),
                        ),

                        // Vote count
                        Text(
                          currentComment.upvotes.length.toString(),
                          style: TextStyle(
                            color: isUpvoted ? upvoteColor : textMedium,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        // Downvote button
                        GestureDetector(
                          onTap: () {}, // Placeholder for downvote
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: iconColor,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Reply button
                        if (depth == 0)
                          GestureDetector(
                            onTap: () => _startReply(currentComment.id, currentComment.userName),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.reply_rounded, color: iconColor, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Reply',
                                    style: TextStyle(
                                      color: iconColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(width: 16),

                        const Spacer(),

                        // More options
                        GestureDetector(
                          onTap: () {}, // Placeholder for more options
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.more_horiz_rounded, color: iconColor, size: 16),
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
      },
    );
  }

  Widget _buildKeyboardAwareCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: cardBackground,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToCommentId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply_rounded, size: 16, color: primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Replying to $_replyingToUserName',
                    style: const TextStyle(
                      fontSize: 13,
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyingToCommentId = null;
                      _replyingToUserName = null;
                    }),
                    child: const Icon(Icons.close_rounded, size: 18, color: primaryBlue),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(
                    color: textMedium,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: const TextStyle(
                      color: textLight,
                      fontWeight: FontWeight.w500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: primaryBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: backgroundLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onTap: ()async{
                    await _createComment();
                  },

                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _createComment,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration:  BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCommentsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: chipBackground,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.comment_outlined,
              size: 50,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to share what you think!',
            style: TextStyle(
              fontSize: 15,
              color: textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createComment() async {
    if (_commentController.text.trim().isEmpty) return;
    try {
      final comment = CommentModel(
        id: '',
        postId: widget.post.id,
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        userProfileImage: widget.currentUser.profileImageUrl,
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
        upvotes: [],
        downvotes: [],
        parentCommentId: _replyingToCommentId,
        replyCount: 0,
      );

      final commentData = comment.toJson();
      commentData['createdAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('social')
          .doc(widget.post.id)
          .collection('comments')
          .add(commentData);

      await _firestore.collection('social').doc(widget.post.id).update({
        'commentCount': FieldValue.increment(1),
      });

      if (_replyingToCommentId != null) {
        await _firestore
            .collection('social')
            .doc(widget.post.id)
            .collection('comments')
            .doc(_replyingToCommentId)
            .update({'replyCount': FieldValue.increment(1)});
      }

      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUserName = null;
      });

      // Auto-scroll to bottom to show new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting comment: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: primaryRed,
          ),
        );
      }
    }
  }

  Future<void> _toggleCommentUpvote(String commentId, bool isCurrentlyUpvoted) async {
    try {
      final commentRef = _firestore
          .collection('social')
          .doc(widget.post.id)
          .collection('comments')
          .doc(commentId);
      if (isCurrentlyUpvoted) {
        await commentRef.update({'upvotes': FieldValue.arrayRemove([widget.currentUser.id])});
      } else {
        await commentRef.update({'upvotes': FieldValue.arrayUnion([widget.currentUser.id])});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating upvote: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: primaryRed,
          ),
        );
      }
    }
  }

  void _startReply(String commentId, String userName) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
    });
  }

  String _formatDateTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}
