import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ADDED for kDebugMode
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
import 'package:stayhub/features/agent/add_clip_page.dart';

class AgentDashboard extends StatefulWidget {
  const AgentDashboard({super.key});

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  int _selectedIndex = 0;
  final _user = FirebaseAuth.instance.currentUser;
  
  String _title = "Overview";
  late final List<Widget> _pages;

  bool _isAdmin = false; 

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildOverviewTab(),
      const AgentHostelsPage(),
      const AgentBookingsPage(), // Renamed for clarity in UI
      const AgentWalletPage(),
      const AgentProfilePage(), 
    ];
    
    _checkUserRole();
  }

  Widget _buildOverviewTab() {
     if (_user == null) return const SizedBox.shrink();
     
     return StreamBuilder<DocumentSnapshot>(
       stream: FirebaseFirestore.instance.collection('agents').doc(_user!.uid).snapshots(),
       builder: (context, snapshot) {
         Map<String, dynamic> data = {};
         if (snapshot.hasData && snapshot.data!.exists) {
           data = snapshot.data!.data() as Map<String, dynamic>;
         }
         // Pass admin status down
         if (_isAdmin) data['isAdmin'] = true;
         
         return DashboardOverview(userData: data);
       },
     );
  }

  Future<void> _checkUserRole() async {
    if (_user == null) return;
    try {
      final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(_user!.uid).get();
      
      // SECURITY: Only allow auto-promotion in Debug mode to prevent production exploits
      if (kDebugMode && !adminDoc.exists && _user!.email == 'anonyemichael6@gmail.com') {
        debugPrint("AUTO-PROMOTING USER TO ADMIN...");
        await FirebaseFirestore.instance.collection('admins').doc(_user!.uid).set({
           'email': _user!.email,
           'role': 'super_admin',
           'promotedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
           setState(() {
            _isAdmin = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are now an Admin!")));
        }
        return;
      }

      if (mounted && (adminDoc.exists || _isAdmin)) {
        setState(() {
          _isAdmin = true;
        });
      }
    } catch (e) {
      debugPrint("Role check error: $e");
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const AuthPage();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: false, 
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "Dashboard" : _title, 
          style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5)
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Icon(Icons.logout_rounded, color: isDark ? Colors.white : Colors.black),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          )
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            // Update title based on index for valid app bar
            switch(index) {
              case 0: _title = "Overview"; break;
              case 1: _title = "My Hostels"; break;
              case 2: _title = "Bookings"; break;
              case 3: _title = "Wallet"; break;
              case 4: _title = "Profile"; break;
            }
          });
        },
        backgroundColor: navColor,
        elevation: 0,
        indicatorColor: Theme.of(context).primaryColor.withOpacity(0.15),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Overview'
          ),
          NavigationDestination(
              icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment_rounded),
              label: 'Hostels'
          ),
          NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Bookings'
          ),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Wallet'
          ),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'
          ),
        ],
      ),
      floatingActionButton: _isAdmin ? FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard())),
        backgroundColor: Colors.redAccent, 
        elevation: 5,
        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
      ) : null,
    );
  }
}

class DashboardOverview extends StatelessWidget {
  final Map<String, dynamic> userData;
  const DashboardOverview({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final String name = userData['name'] ?? 'Agent';
    final rawBal = userData['wallet_balance'];
    final double walletBalance = (rawBal is String ? double.tryParse(rawBal) : (rawBal as num?)?.toDouble()) ?? 0.0;
    final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Theme Colors
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // Greeting Logic
    final DateTime now = DateTime.now();
    String greeting = "Welcome back,";
    
    if (now.month == 12 && (now.day >= 24 && now.day <= 26)) {
      greeting = "Merry Christmas 🎄,";
    } else if ((now.month == 12 && now.day == 31) || (now.month == 1 && now.day == 1)) {
      greeting = "Happy New Year 🎉,";
    } else if (now.month == 2 && now.day == 14) {
      greeting = "Happy Valentine's ❤️,";
    } else {
       final hour = now.hour;
       if (hour < 12) greeting = "Good Morning 🌤️,";
       else if (hour < 17) greeting = "Good Afternoon ☀️,";
       else greeting = "Good Evening 🌙,";
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(greeting, style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.grey[600], fontWeight: FontWeight.w500)),
                     Text(name, 
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                       style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5)
                     ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 24,
                backgroundImage: userData['photoUrl'] != null ? NetworkImage(userData['photoUrl']) : null,
                backgroundColor: Colors.blueAccent.withOpacity(0.1),
                child: userData['photoUrl'] == null ? const Icon(Icons.person, color: Colors.blueAccent) : null,
              )
            ],
          ),

          const SizedBox(height: 24),
          
          _buildWalletCard(walletBalance, currencyFormat, isDark),
          
          const SizedBox(height: 24),
          
          if (uid != null)
             _buildLiveStats(uid, isDark),
            
           const SizedBox(height: 24),
            
           Text("Analytics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
           const SizedBox(height: 16),
           
           Container(
             height: 240,
             padding: const EdgeInsets.fromLTRB(16, 24, 24, 10),
             decoration: BoxDecoration(
               color: cardColor,
               borderRadius: BorderRadius.circular(24),
               boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 8))],
             ),
             child: uid != null ? _buildRealRevenueChart(uid, isDark) : const Center(child: Text("No Data")),
           ),

           const SizedBox(height: 30),

           // ADDED: Recent Properties Section
           if (uid != null) ...[
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text("My Properties", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                 GestureDetector(
                   onTap: () {
                      // Hacky way to switch tab: Find ancestor State or use a callback. 
                      // Since we can't easily switch tabs from here without passing a callback, 
                      // we will just let the user know to use the bottom nav or push the page.
                      // Better: Just push the AgentHostelsPage effectively or do nothing (View All implies tab switch).
                      // For now, let's just show the list.
                   },
                   child: Text("Recent", style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey[600])),
                 ),
               ],
             ),
             const SizedBox(height: 16),
             SizedBox(
               height: 160,
               child: StreamBuilder<QuerySnapshot>(
                 // Fetch ALL, filter locally
                 stream: FirebaseFirestore.instance.collection('hostels').snapshots(),
                 builder: (context, snapshot) {
                   if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                   if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                   
                   final allDocs = snapshot.data!.docs;
                   final docs = allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['agentId'] == uid;
                   }).toList();

                   // Sort locally since we can't sort in query w/o index
                   docs.sort((a, b) {
                      final tA = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      final tB = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      if (tA == null || tB == null) return 0;
                      return tB.compareTo(tA);
                   });

                   if (docs.isEmpty) {
                     return Container(
                       width: double.infinity,
                       decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.add_home_work_outlined, size: 30, color: Colors.grey),
                           Text("No properties yet", style: TextStyle(color: Colors.grey)),
                         ],
                       ),
                     );
                   }
                   
                   return ListView.builder(
                     scrollDirection: Axis.horizontal,
                     physics: const BouncingScrollPhysics(),
                     itemCount: docs.length,
                     itemBuilder: (context, index) {
                       final doc = docs[index];
                       final data = doc.data() as Map<String, dynamic>;
                       return Container(
                         width: 200,
                         margin: const EdgeInsets.only(right: 16),
                         decoration: BoxDecoration(
                           color: cardColor,
                           borderRadius: BorderRadius.circular(20),
                           boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                           image: DecorationImage(
                             image: NetworkImage(data['image'] ?? 'https://via.placeholder.com/200'),
                             fit: BoxFit.cover,
                             colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken),
                           ),
                         ),
                         child: Stack(
                           children: [
                             Positioned(
                               bottom: 12, left: 12, right: 12,
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(data['name'] ?? 'Hostel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                   Text("GHS ${data['price']}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                                 ],
                               ),
                             ),
                           ],
                         ),
                       );
                     },
                   );
                 },
               ),
             ),
             const SizedBox(height: 30),
           ],

          // QUICK ACTIONS GRID
          Text("Action Center", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
            children: [
              _buildModernActionCard(context, Icons.add_business_rounded, "Add Hostel", "List Property", Colors.blueAccent, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHostelPage()));
              }, isDark),
              _buildModernActionCard(context, Icons.qr_code_scanner_rounded, "Scan Ticket", "Check-in", Colors.orangeAccent, () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketScannerPage()));
              }, isDark),
              _buildModernActionCard(context, Icons.chat_bubble_outline_rounded, "Messages", "Inquiries", Colors.purpleAccent, () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentInboxPage()));
              }, isDark),
              _buildModernActionCard(context, Icons.video_collection_outlined, "Videos", "Promote", Colors.pinkAccent, () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const AddClipPage()));
              }, isDark),
            ],
          ),
          
           // Admin Entry Point Logic
           if ((userData['role'] == 'admin') || (userData['isAdmin'] == true)) ...[
             const SizedBox(height: 16),
             _buildModernActionCard(context, Icons.security, "Admin Console", "Platform Management", Colors.redAccent, () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
             }, isDark, isWide: true),
           ],

          const SizedBox(height: 100), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildLiveStats(String uid, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('hostels').where('agentId', isEqualTo: uid).snapshots(),
      builder: (context, hostelSnapshot) {
        final activeHostels = hostelSnapshot.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collectionGroup('bookings').where('agentId', isEqualTo: uid).snapshots(),
          builder: (context, bookingSnapshot) {
            final totalBookings = bookingSnapshot.data?.docs.length ?? 0;
            
            // Calculate Rating
            double totalRating = 0;
            int ratedHostels = 0;
            
            if (hostelSnapshot.hasData) {
              for (var doc in hostelSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data.containsKey('rating')) {
                   final ratingVal = data['rating'];
                   if (ratingVal is num) {
                     totalRating += ratingVal.toDouble();
                   } else if (ratingVal is String) {
                     totalRating += double.tryParse(ratingVal) ?? 0.0;
                   }
                   ratedHostels++;
                }
              }
            }
            final String avgRatingDisplay = ratedHostels > 0 
                ? (totalRating / ratedHostels).toStringAsFixed(1) 
                : "-";

            // Horizontal Scroll for Stats
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildStatPill("Properties", activeHostels.toString(), Icons.apartment, const Color(0xFF6C5CE7), isDark),
                  const SizedBox(width: 12),
                  _buildStatPill("Bookings", totalBookings.toString(), Icons.confirmation_number, const Color(0xFF00B894), isDark),
                  const SizedBox(width: 12),
                  _buildStatPill("Rating", avgRatingDisplay, Icons.star, const Color(0xFFFDCB6E), isDark),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatPill(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
              Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[600])),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWalletCard(double balance, NumberFormat format, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2E2AB7), Color(0xFF5F5ACD)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2E2AB7).withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                   Icon(Icons.wallet, color: Colors.white, size: 14),
                   SizedBox(width: 6),
                   Text("Main Wallet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                ]),
              ),
              Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.6)),
            ],
          ),
          const SizedBox(height: 24),
          Text(format.format(balance), style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
          const SizedBox(height: 6),
          const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildModernActionCard(BuildContext context, IconData icon, String title, String subtitle, Color accentColor, VoidCallback onTap, bool isDark, {bool isWide = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isWide ? double.infinity : null,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space evenly
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[500])
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealRevenueChart(String uid, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      // 1. Fetch Transactions
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('transactions')
          .orderBy('date', descending: false).snapshots(), // Oldest first to plot correctly
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          // Empty State Chart
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
             Icon(Icons.bar_chart, color: isDark ? Colors.white24 : Colors.grey[300], size: 48),
             const SizedBox(height: 8),
             Text("No revenue data yet", style: TextStyle(color: isDark ? Colors.white24 : Colors.grey[400]))
          ]));
        }

        // 2. Aggregate Data by Month
        // Map<MonthIndex (0-11), TotalAmount>
        final Map<int, double> monthlyTotals = {};
        for(var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final dateVal = data['date'];
          DateTime date;
          if (dateVal is Timestamp) date = dateVal.toDate();
          else continue;
          
          // Only process credit transactions? Or net? Assuming 'credit' is revenue.
          if (data['type'] == 'credit') {
             monthlyTotals.update(date.month - 1, (val) => val + amount, ifAbsent: () => amount);
          }
        }

        final List<FlSpot> spots = [];
        // Populate spots for 12 months (or at least up to current)
        for(int i=0; i<12; i++) {
          spots.add(FlSpot(i.toDouble(), monthlyTotals[i] ?? 0));
        }
        
        // Find max Y for scaling
        double maxY = 0;
        for (var s in spots) { if(s.y > maxY) maxY = s.y; }
        if (maxY == 0) maxY = 100; // default scale
        
        return LineChart(
          LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: isDark ? Colors.white10 : Colors.grey[100], strokeWidth: 1)),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 2, // Show every other month
                  getTitlesWidget: (value, meta) {
                    final style = TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 10);
                    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
                    int idx = value.toInt();
                    if(idx >=0 && idx < 12) return Text(months[idx], style: style);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0, maxX: 11, minY: 0, maxY: maxY * 1.2, // Adds some headroom
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF2E2AB7),
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [const Color(0xFF2E2AB7).withOpacity(0.3), const Color(0xFF2E2AB7).withOpacity(0.0)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter
                  )
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

