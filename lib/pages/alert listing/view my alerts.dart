
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import '../../Class Models/alert.dart';
import '../../Class Models/user.dart';
import '../homepage/drawer.dart';

class AlertHistoryScreen extends StatefulWidget {
  final UserModel currentUser;
  const AlertHistoryScreen({Key? key,required this.currentUser}) : super(key: key);

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> with TickerProviderStateMixin {
  List<AlertModel> alerts = [];
  bool isLoading = true;
  Map<String, String> cachedAddresses = {};
  String selectedStatus = 'All';
  final List<String> statusOptions = ['All', 'danger', 'safe'];
  late TabController _tabController;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return "${place.street}, ${place.locality}";
      }
      return "Unknown location";
    } catch (e) {
      return "Unknown location";
    }
  }

  Future<String> getLocationForAlert(AlertModel alert) async {
    if (alert.address != null && alert.address!.isNotEmpty) {
      return alert.address!;
    }
    if (alert.location != null &&
        alert.location!['latitude'] != null &&
        alert.location!['longitude'] != null) {
      final lat = alert.location!['latitude'] as double;
      final lng = alert.location!['longitude'] as double;
      final cacheKey = '${lat}_$lng';
      if (cachedAddresses.containsKey(cacheKey)) {
        return cachedAddresses[cacheKey]!;
      }
      final address = await getAddressFromLatLng(lat, lng);
      cachedAddresses[cacheKey] = address;
      return address;
    }
    return "Location not available";
  }

  Future<void> fetchAlerts() async {
    try {
      setState(() => isLoading = true);
      final alertSnapshot = await FirebaseFirestore.instance
          .collection('Alerts')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        alerts = alertSnapshot.docs
            .map((doc) => AlertModel.fromJson(doc.data(), doc.id))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading alerts: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  String formatDuration(AlertModel alert) {
    if (alert.safeTime == null) {
      final duration = DateTime.now().difference(alert.timestamp.toDate());
      return _formatDurationString(duration);
    } else {
      final duration = alert.safeTime!.toDate().difference(alert.timestamp.toDate());
      return _formatDurationString(duration);
    }
  }

  String _formatDurationString(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'danger': return const Color(0xFFEF4444);
      case 'safe': return const Color(0xFF10B981);
      default: return const Color(0xFF6B7280);
    }
  }

  Color getSeverityColor(int severity) {
    switch (severity) {
      case 1: return const Color(0xFFF59E0B);
      case 2: return const Color(0xFFEF4444);
      case 3: return const Color(0xFFDC2626);
      default: return const Color(0xFF6B7280);
    }
  }

  String getSeverityText(int severity) {
    switch (severity) {
      case 1: return 'Low';
      case 2: return 'Medium';
      case 3: return 'High';
      default: return 'Unknown';
    }
  }

  List<AlertModel> get filteredAlerts {
    switch (_tabController.index) {
      case 0: return alerts;
      case 1: return alerts.where((alert) => alert.status == 'danger').toList();
      case 2: return alerts.where((alert) => alert.status == 'safe').toList();
      default: return alerts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(currentUser: widget.currentUser,activePage: 3,),
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(

        backgroundColor: Colors.white,

        color: Colors.black,
        strokeWidth:2,
        onRefresh: () async{
          await fetchAlerts();
          setState(() {

          });
        },
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            _buildStatsSection(),
            _buildTabSection(),
            _buildContentSection(),
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
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Alert History',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Color(0xFFF8FAFC),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final totalNotified = alerts.fold<int>(0, (sum, alert) => sum + alert.notified);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F2937).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatItem('Total Alert', '${alerts.length}', FontAwesomeIcons.solidBell, Colors.black),
                Container(
                  width: 1,
                  height: 60,
                  color: const Color(0xFFE5E7EB),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                _buildStatItem('Through Notified', '$totalNotified', FontAwesomeIcons.solidPaperPlane, Colors.black),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: FaIcon(icon, color: color, size: 24)),
              ),
              const SizedBox(width: 20),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F2937).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: const Color(0xFF1F2937),
          unselectedLabelColor: const Color(0xFF6B7280),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          onTap: (index) => setState(() {}),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    if (isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3B82F6),
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (filteredAlerts.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(),
      );
    }

    return _buildListView();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 60,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No alerts found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your alert history will appear here',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final alert = filteredAlerts[index];
          return _buildTimelineCard(alert, index);
        },
        childCount: filteredAlerts.length,
      ),
    );
  }


  Widget _buildTimelineCard(AlertModel alert, int index) {
    return Container(
      margin: EdgeInsets.fromLTRB(20, index == 0 ? 20 : 8, 20, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card content
            Expanded(
              child: GestureDetector(
                onTap: () => _showAlertDetails(alert),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1F2937).withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.etype?.toUpperCase() ?? 'ALERT',
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _buildSeverityChip(alert.severity),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildInfoRow(
                        Icons.access_time_rounded,
                        DateFormat('MMM dd, hh:mm a').format(alert.timestamp.toDate()),
                      ),
                      const SizedBox(height: 8),

                      _buildInfoRow(
                        Icons.timer_outlined,
                        'Duration: ${formatDuration(alert)}',
                      ),
                      const SizedBox(height: 8),

                      _buildInfoRow(
                        Icons.people_outline_rounded,
                        '${alert.notified} people notified',
                      ),

                      if (alert.message != null && alert.message!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.message_outlined,
                                size: 16,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  alert.message!,
                                  style: const TextStyle(
                                    color: Color(0xFF374151),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF6B7280),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildSeverityChip(int severity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: getSeverityColor(severity).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: getSeverityColor(severity).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        getSeverityText(severity),
        style: TextStyle(
          color: getSeverityColor(severity),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _showAlertDetails(AlertModel alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAlertDetailsModal(alert),
    );
  }

  Widget _buildAlertDetailsModal(AlertModel alert) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    alert.etype?.toUpperCase() ?? 'ALERT',
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _buildSeverityChip(alert.severity),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (alert.message != null && alert.message!.isNotEmpty) ...[
                    _buildDetailSection('Message', alert.message!, Icons.message_outlined),
                    const SizedBox(height: 20),
                  ],

                  FutureBuilder<String>(
                    future: getLocationForAlert(alert),
                    builder: (context, snapshot) {
                      return _buildDetailSection(
                        'Location',
                        snapshot.data ?? 'Loading...',
                        Icons.location_on_outlined,
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildDetailSection(
                    'Started',
                    DateFormat('EEEE, MMM dd, yyyy at hh:mm a').format(alert.timestamp.toDate()),
                    Icons.play_circle_outline,
                  ),
                  const SizedBox(height: 16),

                  if (alert.safeTime != null) ...[
                    _buildDetailSection(
                      'Ended',
                      DateFormat('EEEE, MMM dd, yyyy at hh:mm a').format(alert.safeTime!.toDate()),
                      Icons.stop_circle_outlined,
                    ),
                    const SizedBox(height: 16),
                  ],

                  _buildDetailSection(
                    'Duration',
                    formatDuration(alert),
                    Icons.timer_outlined,
                  ),
                  const SizedBox(height: 16),

                  _buildDetailSection(
                    'People Notified',
                    '${alert.notified} contacts',
                    Icons.people_outline,
                  ),

                  if (alert.pstation != null && alert.pstation!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('Police Station', alert.pstation!, Icons.local_police_outlined),
                  ],

                  if (alert.hpital != null && alert.hpital!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('Hospital', alert.hpital!, Icons.local_hospital_outlined),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String content, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.black, size: 20,weight: 1,),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}