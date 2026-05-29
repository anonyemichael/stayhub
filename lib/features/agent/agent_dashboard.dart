import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:stayhub/auth/auth_page.dart';
import 'package:stayhub/features/agent/agent_wallet_page.dart';
import 'package:stayhub/features/admin/admin_dashboard.dart'; 
import 'package:stayhub/features/agent/agent_profile_page.dart';
import 'package:stayhub/features/agent/agent_hostels_page.dart';
import 'package:stayhub/features/agent/agent_bookings_page.dart';
import 'package:stayhub/features/agent/add_hostel_page.dart';
import 'package:stayhub/features/agent/ticket_scanner_page.dart';
import 'package:stayhub/features/agent/agent_inbox_page.dart';
import 'package:stayhub/features/agent/agent_clips_page.dart';
import 'package:stayhub/features/agent/agent_edit_profile_page.dart';
import 'package:stayhub/features/agent/agent_bank_page.dart';
import 'package:stayhub/features/home/notifications_page.dart';
import 'package:stayhub/services/firestore_service.dart';
import 'package:stayhub/services/notification_service.dart';

class AgentDashboard extends StatefulWidget {
  const AgentDashboard({super.key});

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  int _selectedIndex = 0;
  final _user = FirebaseAuth.instance.currentUser;
  final _firestoreService = FirestoreService();
  bool _isAdmin = false; 

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildOverviewTab(),
      const AgentHostelsPage(),
      const AgentBookingsPage(),
      const AgentWalletPage(),
      const AgentProfilePage(), 
    ];
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    if (_user == null) return;
    try {
      final email = _user?.email;
      if (email == null) return;
      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(email).get();
      if (mounted && (adminDoc.exists || _isAdmin)) {
        setState(() => _isAdmin = true);
      }
    } catch (e) {
      debugPrint("Role check error: $e");
    }
  }

  Widget _buildOverviewTab() {
    if (_user == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('agents').doc(_user!.uid).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> data = {};
        List<Map<String, String>> missingActions = [];
        
        if (snapshot.hasData && snapshot.data!.exists) {
          data = snapshot.data!.data() as Map<String, dynamic>;
          if (!data.containsKey('partnerType')) {
            missingActions.add({"field": "Partner Role", "route": "profile"});
          }
          if (!data.containsKey('bank_name')) {
            missingActions.add({"field": "Bank Details", "route": "bank"});
          }
        } else {
           missingActions.add({"field": "Partner Profile", "route": "profile"});
           missingActions.add({"field": "Bank Details", "route": "bank"});
        }
        
        if (_isAdmin) data['isAdmin'] = true;

        return FutureBuilder<DocumentSnapshot?>(
          future: (!data.containsKey('name'))
             ? FirebaseFirestore.instance.collection('users').doc(_user!.uid).get()
             : Future.value(null),
          builder: (context, userSnap) {
            final doc = userSnap.data;
            if (userSnap.hasData && doc != null && doc.exists) {
               final userData = doc.data() as Map<String, dynamic>? ?? {};
               data['name'] ??= userData['name'];
               data['photoUrl'] ??= userData['photoUrl'];
            }
            if (!data.containsKey('name') || data['name'] == null) {
              data['name'] = _user!.email;
            }
            
            return DashboardOverview(
              userData: data, 
              missingActions: missingActions,
              onViewAll: () => setState(() => _selectedIndex = 1),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const AuthPage();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final navBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          if (_selectedIndex != 4) _buildModernTopBar(isDark),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark, navBgColor),
    );
  }

  Widget _buildModernTopBar(bool isDark) {
    final title = _selectedIndex == 0 ? "Dashboard" : 
                  _selectedIndex == 1 ? "Properties" :
                  _selectedIndex == 2 ? "Bookings" : "Wallet";

    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: 110,
        padding: const EdgeInsets.fromLTRB(24, 50, 16, 0),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)).withOpacity(0.95),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.w900, 
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -1,
                  ),
                ),
                Container(
                  width: 24, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
            Row(
              children: [
                if (_isAdmin) IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard())),
                  icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.redAccent, size: 22),
                ),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentInboxPage())),
                  icon: StreamBuilder<int>(
                    stream: _user != null ? _firestoreService.getTotalUnreadCount(_user!.uid) : Stream.value(0),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Badge(
                        label: Text(count.toString()),
                        isLabelVisible: count > 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.chat_bubble_outline_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                  icon: StreamBuilder<int>(
                    stream: _user != null ? NotificationService().getUnreadNotificationCount(_user!.uid) : Stream.value(0),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Badge(
                        label: Text(count.toString()),
                        isLabelVisible: count > 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_none_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark, Color navBgColor) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: navBgColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, -10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.grid_view_rounded, "Overview"),
          _buildNavItem(1, Icons.apartment_rounded, "Properties"),
          _buildNavItem(2, Icons.calendar_month_rounded, "Bookings"),
          _buildNavItem(3, Icons.account_balance_wallet_rounded, "Wallet"),
          _buildNavItem(4, Icons.person_rounded, "Profile"),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF2563EB);

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? accentColor : (isDark ? Colors.white38 : Colors.grey[400]),
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w900)),
            ]
          ],
        ),
      ),
    );
  }
}

class DashboardOverview extends StatelessWidget {
  final Map<String, dynamic> userData;
  final List<Map<String, String>> missingActions;
  final VoidCallback onViewAll;
  
  const DashboardOverview({
    super.key, 
    required this.userData, 
    required this.missingActions,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = userData['name'] ?? 'Partner';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 130, 24, 100),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("Welcome back,", style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: (userData['partnerType'] == 'owner' ? Colors.purple : Colors.blueAccent).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: (userData['partnerType'] == 'owner' ? Colors.purple : Colors.blueAccent).withOpacity(0.3)),
                        ),
                        child: Text(
                          (userData['partnerType'] ?? 'Partner').toUpperCase(),
                          style: TextStyle(
                            fontSize: 9, 
                            fontWeight: FontWeight.w900, 
                            color: userData['partnerType'] == 'owner' ? Colors.purple : Colors.blueAccent,
                            letterSpacing: 0.5
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(name, style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ],
              ),
              const Spacer(),
              _buildProfileAvatar(userData['photoUrl'], isDark),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // REAL DATA WARNING SYSTEM
          if (missingActions.isNotEmpty) ...[
             for (var action in missingActions) 
                _buildActionWarning(context, action['field']!, action['route']!),
             const SizedBox(height: 20),
          ],

          _buildQuickActionGrid(context, isDark),
          
          const SizedBox(height: 40),
          
          _buildLivePortfolio(uid, isDark, cardColor),
          
          const SizedBox(height: 32),
          
          _buildRealFinancialInsight(uid, isDark, cardColor),
          
          const SizedBox(height: 40),
          
          _buildLiveAssets(uid, isDark, cardColor),
        ],
      ),
    );
  }

  Widget _buildActionWarning(BuildContext context, String field, String route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFEE2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                child: const Icon(Icons.security_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text("Action Required: $field", style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w900, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Please complete your $field to activate bookings and receive payments.",
            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (route == 'profile') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentEditProfilePage()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentBankPage()));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("FINISH SETUP", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(String? url, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF2563EB), width: 2)),
      child: CircleAvatar(
        radius: 26,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
        backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
        child: (url == null || url.isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
      ),
    );
  }

  Widget _buildQuickActionGrid(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionTile(context, Icons.add_home_work_rounded, "New Hostel", const Color(0xFF3B82F6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHostelPage()))),
        _buildActionTile(context, Icons.qr_code_scanner_rounded, "Verify", const Color(0xFFF59E0B), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketScannerPage()))),
        StreamBuilder<int>(
          stream: FirebaseAuth.instance.currentUser != null ? FirestoreService().getTotalUnreadCount(FirebaseAuth.instance.currentUser!.uid) : Stream.value(0),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _buildActionTile(context, Icons.chat_bubble_outline_rounded, "Inbox", const Color(0xFF8B5CF6), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentInboxPage()))),
                if (count > 0)
                  Positioned(
                    top: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            );
          },
        ),
        _buildActionTile(context, Icons.videocam_rounded, "Clips", const Color(0xFFEC4899), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentClipsPage()))),
      ],
    );
  }

  Widget _buildActionTile(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white70 : const Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _buildLivePortfolio(String? uid, bool isDark, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Housing Portfolio", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('hostels').where('agentId', isEqualTo: uid).snapshots(),
          builder: (context, hSnap) {
            final hCount = hSnap.data?.docs.length ?? 0;
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bookings').where('agentId', isEqualTo: uid).snapshots(),
              builder: (context, bSnap) {
                final bCount = bSnap.data?.docs.length ?? 0;
                final pCount = (bSnap.data?.docs ?? []).where((d) => (d.data() as Map)['status'] == 'pending').length;
                
                return Row(
                  children: [
                    _buildSummaryCard("Properties", hCount.toString(), Icons.apartment_rounded, const Color(0xFF3B82F6), cardColor),
                    const SizedBox(width: 12),
                    _buildSummaryCard("Bookings", bCount.toString(), Icons.event_available_rounded, const Color(0xFF10B981), cardColor),
                    const SizedBox(width: 12),
                    _buildSummaryCard("Pending", pCount.toString(), Icons.history_rounded, const Color(0xFFF59E0B), cardColor),
                  ],
                );
              },
            );
          }
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String val, IconData icon, Color color, Color cardColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildRealFinancialInsight(String? uid, bool isDark, Color cardColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings').where('agentId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        double totalRevenue = 0;
        List<double> monthlyRevenue = List.filled(6, 0.0);
        final now = DateTime.now();

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString().toUpperCase();
            
            // Revenue only from Approved or Paid bookings
            if (status == 'APPROVED' || status == 'PAID' || status == 'COMPLETED') {
              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
              totalRevenue += price;
              
              final date = (data['createdAt'] as Timestamp?)?.toDate();
              if (date != null && date.isAfter(now.subtract(const Duration(days: 180)))) {
                 int mIdx = 5 - (now.month - date.month + (now.year - date.year) * 12);
                 if (mIdx >= 0 && mIdx < 6) monthlyRevenue[mIdx] += price;
              }
            }
          }
        }

        final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Rental Revenue", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(currencyFormat.format(totalRevenue), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 120,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: monthlyRevenue.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                        isCurved: true,
                        color: const Color(0xFF2563EB),
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [const Color(0xFF2563EB).withOpacity(0.1), const Color(0xFF2563EB).withOpacity(0)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildLiveAssets(String? uid, bool isDark, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("My Listings", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
            GestureDetector(
              onTap: onViewAll,
              child: Text("View All", style: TextStyle(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.underline)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('hostels').where('agentId', isEqualTo: uid).limit(5).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text("No properties listed yet.", style: TextStyle(color: Colors.grey)));
            
            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map;
                return InkWell(
                  onTap: onViewAll,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(data['image'] ?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.apartment_rounded))),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['name'] ?? 'Hostel', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              Text("GHS ${data['price']}", style: TextStyle(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }
        ),
      ],
    );
  }
}
