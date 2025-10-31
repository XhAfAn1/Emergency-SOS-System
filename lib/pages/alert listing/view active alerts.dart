import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../Class Models/alert.dart';
import '../../Class Models/user.dart';

class ViewActiveAlertsScreen extends StatefulWidget {
  final Position? currentPosition;
  final Function(double lat, double lng, String alertId)? onNavigate;
  final UserModel? currentUser;

  const ViewActiveAlertsScreen({
    Key? key,
    this.currentPosition,
    this.onNavigate,required this.currentUser,
  }) : super(key: key);

  @override
  State<ViewActiveAlertsScreen> createState() => _ViewActiveAlertsScreenState();
}

class _ViewActiveAlertsScreenState extends State<ViewActiveAlertsScreen> with TickerProviderStateMixin {
  List<AlertModel> activeAlerts = [];
  bool isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    fetchActiveAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchActiveAlerts() async {
    try {
      setState(() => isLoading = true);
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final alertSnapshot = await FirebaseFirestore.instance
          .collection('Alerts')
          .where('status', isEqualTo: 'danger')
          .orderBy('timestamp', descending: true)
          .get();

      List<AlertModel> alerts = [];
      for (var doc in alertSnapshot.docs) {
        final data = doc.data();
        if (data['userId'] == currentUserId || data['admin'] == true) continue;
        alerts.add(AlertModel.fromJson(data, doc.id));
      }

      setState(() {
        activeAlerts = alerts;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
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
  }

  List<AlertModel> get filteredAlerts {
    switch (_tabController.index) {
      case 0: return activeAlerts;
      case 1: return activeAlerts.where((alert) => alert.severity == 1).toList();
      case 2: return activeAlerts.where((alert) => alert.severity == 2).toList();
      case 3: return activeAlerts.where((alert) => alert.severity == 3).toList();
      default: return activeAlerts;
    }
  }

  String formatDuration(AlertModel alert) {
    final duration = DateTime.now().difference(alert.timestamp.toDate());
    if (duration.inDays > 0) return '${duration.inDays}d ${duration.inHours % 24}h ago';
    if (duration.inHours > 0) return '${duration.inHours}h ${duration.inMinutes % 60}m ago';
    return '${duration.inMinutes}m ago';
  }

  String calculateDistance(AlertModel alert) {
    if (widget.currentPosition == null || alert.location == null) return 'Distance unknown';
    try {
      final alertLat = alert.location!['latitude'];
      final alertLng = alert.location!['longitude'];
      if (alertLat == null || alertLng == null) return 'Distance unknown';

      final distance = Geolocator.distanceBetween(
        widget.currentPosition!.latitude,
        widget.currentPosition!.longitude,
        alertLat is double ? alertLat : double.parse(alertLat.toString()),
        alertLng is double ? alertLng : double.parse(alertLng.toString()),
      );

      return distance >= 1000
          ? '${(distance / 1000).toStringAsFixed(1)} km away'
          : '${distance.toInt()} m away';
    } catch (e) {
      return 'Distance unknown';
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

  Future<void> respondToAlert(AlertModel alert) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await FirebaseFirestore.instance
          .collection('Alerts')
          .doc(alert.alertId)
          .update({'responders': FieldValue.arrayUnion([currentUserId])});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You are now responding to this alert'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
      fetchActiveAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error responding to alert: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  bool isUserResponding(AlertModel alert) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return alert.responders?.contains(currentUserId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //  drawer: AppDrawer(currentUser: widget.currentUser,activePage: 1,),
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        backgroundColor: Colors.white,
        color: Colors.black,
        strokeWidth:2,
        onRefresh: () async{
          await fetchActiveAlerts();
          setState(() {

          });
        },

        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
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
      // leading: Padding(
      //   padding: const EdgeInsets.only(left: 12.0,top: 10,right: 0),
      //   child: Builder(
      //     builder: (context) {
      //       return GestureDetector(
      //         onTap: () => Scaffold.of(context).openDrawer(),
      //         child: Container(
      //           width: 44,
      //           height: 44,
      //           decoration: BoxDecoration(
      //             color: Colors.white,
      //             borderRadius: BorderRadius.circular(12),
      //             boxShadow: [
      //               BoxShadow(
      //                 color: Colors.black.withOpacity(0.1),
      //                 blurRadius: 8,
      //                 offset: const Offset(0, 2),
      //               ),
      //             ],
      //           ),
      //           child: const Icon(
      //             Icons.menu_rounded,
      //             color: Color(0xFF1F2937),
      //             size: 24,
      //           ),
      //         ),
      //       );
      //     },
      //   ),
      // ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Active Alerts',
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
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
          ),
        ),
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

        ),]),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF1F2937),
        unselectedLabelColor: const Color(0xFF6B7280),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        onTap: (index) => setState(() {}),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Low'),
          Tab(text: 'Medium'),
          Tab(text: 'High'),
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
            color: Color(0xFFEF4444),
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

    return  _buildListView();
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
              Icons.crisis_alert_outlined,
              size: 60,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'No active alerts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'All clear in your area',
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
            (context, index) => _buildAlertCard(filteredAlerts[index], index),
        childCount: filteredAlerts.length,
      ),
    );
  }

  Widget _buildAlertCard(AlertModel alert, int index) {
    final isResponding = isUserResponding(alert);

    return Container(
      margin: EdgeInsets.fromLTRB(20, index == 0 ? 20 : 8, 20, 8),
      child: GestureDetector(
        onTap: () => _showAlertDetails(alert),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              boxShadow: [
              BoxShadow(
              color: const Color(0xFF1F2937).withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
              )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with severity
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    getSeverityColor(alert.severity).withOpacity(0.1),
                    getSeverityColor(alert.severity).withOpacity(0.05),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  _buildSeverityChip(alert.severity),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formatDuration(alert),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.userName,
                              style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (alert.etype != null)
                              Text(
                                alert.etype!.toUpperCase(),
                                style: TextStyle(
                                  color: getSeverityColor(alert.severity),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          calculateDistance(alert),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
                  if (alert.address != null && alert.address!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.location_on_outlined, alert.address!),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip(Icons.people_outline, '${alert.notified} notified'),
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.volunteer_activism_outlined,
                          '${alert.responders?.length ?? 0} responding'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(
                            isResponding ? Icons.check_circle : Icons.volunteer_activism,
                            size: 18,
                          ),
                          label: Text(isResponding ? 'Responding' : 'Respond'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isResponding
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: isResponding ? null : () => respondToAlert(alert),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.navigation, size: 18),
                          label: const Text('Navigate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3B82F6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Color(0xFF3B82F6)),
                          ),
                          onPressed: () {
                            if (widget.onNavigate != null && alert.location != null) {
                              final lat = alert.location!['latitude'];
                              final lng = alert.location!['longitude'];
                              if (lat != null && lng != null) {
                                widget.onNavigate!(
                                  lat is double ? lat : double.parse(lat.toString()),
                                  lng is double ? lng : double.parse(lng.toString()),
                                  alert.alertId,
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
        getSeverityText(severity).toUpperCase(),
        style: TextStyle(
          color: getSeverityColor(severity),
          fontSize: 10,
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
    final isResponding = isUserResponding(alert);

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
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: getSeverityColor(alert.severity),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.userName,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (alert.etype != null)
                        Text(
                          alert.etype!.toUpperCase(),
                          style: TextStyle(
                            color: getSeverityColor(alert.severity),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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
                  if (alert.address != null && alert.address!.isNotEmpty) ...[
                    _buildDetailSection('Location', alert.address!, Icons.location_on_outlined),
                    const SizedBox(height: 20),
                  ],
                  _buildDetailSection(
                    'Distance',
                    calculateDistance(alert),
                    Icons.straighten_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildDetailSection(
                    'Started',
                    DateFormat('EEEE, MMM dd, yyyy at hh:mm a').format(alert.timestamp.toDate()),
                    Icons.access_time_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailSection(
                    'Duration',
                    formatDuration(alert),
                    Icons.timer_outlined,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailSection(
                          'Notified',
                          '${alert.notified} people',
                          Icons.people_outline,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDetailSection(
                          'Responding',
                          '${alert.responders?.length ?? 0} people',
                          Icons.volunteer_activism_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(
                            isResponding ? Icons.check_circle : Icons.volunteer_activism,
                            size: 20,
                          ),
                          label: Text(isResponding ? 'You are responding' : 'Respond to Alert'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isResponding
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: isResponding ? null : () {
                            respondToAlert(alert);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.navigation, size: 20),
                          label: const Text('Navigate to Location'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3B82F6),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Color(0xFF3B82F6)),
                          ),
                          onPressed: () {
                            if (widget.onNavigate != null && alert.location != null) {
                              final lat = alert.location!['latitude'];
                              final lng = alert.location!['longitude'];
                              if (lat != null && lng != null) {
                                widget.onNavigate!(
                                  lat is double ? lat : double.parse(lat.toString()),
                                  lng is double ? lng : double.parse(lng.toString()),
                                  alert.alertId,
                                );
                                Navigator.pop(context);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
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
              color: Color(0xff25282b).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Color(0xff25282b), size: 20),
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