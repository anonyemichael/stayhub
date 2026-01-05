import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AdminStatsView extends StatefulWidget {
  final Function(int)? onNavigate;
  final bool isSuper;
  const AdminStatsView({super.key, this.onNavigate, this.isSuper = false});

  @override
  State<AdminStatsView> createState() => _AdminStatsViewState();
}

class _AdminStatsViewState extends State<AdminStatsView> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchRealStats();
  }

  Future<Map<String, dynamic>> _fetchRealStats() async {
    final firestore = FirebaseFirestore.instance;

    int studentCount = 0;
    int agentCount = 0;
    int activeHostelCount = 0;
    int pendingHostelCount = 0;

    try {
      final counts = await Future.wait([
        firestore.collection('users').count().get(),
        firestore.collection('agents').count().get(),
        firestore.collection('hostels').where('status', isEqualTo: 'approved').count().get(),
        firestore.collection('hostels').where('status', isEqualTo: 'pending').count().get(),
      ]);

      studentCount = counts[0].count ?? 0;
      agentCount = counts[1].count ?? 0;
      activeHostelCount = counts[2].count ?? 0;
      pendingHostelCount = counts[3].count ?? 0;
    } catch (e) {
      debugPrint("Count Fetch Error: $e");
    }

    double totalRevenue = 0.0;
    Map<int, double> monthlyData = {};

    // Only fetch revenue if Super Admin
    if (widget.isSuper) {
      try {
        final revenueSnapshot = await firestore.collectionGroup('bookings')
            .where('status', isEqualTo: 'PAID')
            .limit(1000) // Safety limit
            .get();

        for (var doc in revenueSnapshot.docs) {
           final data = doc.data();
           final double fee = (data['platformFee'] as num?)?.toDouble() ?? 50.0; 
           
           totalRevenue += fee;

           final Timestamp? ts = data['bookingDate']; 
           if (ts != null) {
             final date = ts.toDate();
             if (date.year == DateTime.now().year) {
                 monthlyData.update(date.month - 1, (val) => val + fee, ifAbsent: () => fee);
             }
           }
        }
      } catch (e) {
        debugPrint("Revenue Fetch Error: $e");
      }
    }

    List<FlSpot> spots = [];
    if (widget.isSuper) {
      for (int i=0; i<12; i++) {
         spots.add(FlSpot(i.toDouble(), monthlyData[i] ?? 0.0));
      }
    }

    return {
      'students': studentCount,
      'agents': agentCount,
      'hostels': activeHostelCount,
      'pendingHostels': pendingHostelCount,
      'revenue': totalRevenue,
      'spots': spots,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF7F9FC);
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dashboard", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 22)),
            const Text("Platform Overview", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: textColor),
              onPressed: () {
                setState(() {
                  _statsFuture = _fetchRealStats();
                });
              },
            ),
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text("Error loading stats: ${snapshot.error}"));
          }

          final data = snapshot.data!;
          final List<FlSpot> spots = data['spots'] as List<FlSpot>;
          final double revenue = data['revenue'];
          final currencyFormat = NumberFormat.currency(symbol: 'GHS ', decimalDigits: 2);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. REVENUE CARD (HERO) - Only for Super Admin
                if (widget.isSuper)
                   _buildRevenueChartCard(revenue, spots, isDark, currencyFormat),
                
                if (widget.isSuper) const SizedBox(height: 30),

                // 2. METRICS GRID
                Text("Key Metrics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                const SizedBox(height: 15),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.1, // Even taller to guarantee fit
                  children: [
                    _buildStatCard("Students", "${data['students']}", Icons.school_rounded, const Color(0xFF6C5CE7), isDark),
                    _buildStatCard("Agents", "${data['agents']}", Icons.business_center_rounded, const Color(0xFF00B894), isDark),
                    _buildStatCard("Active Hostels", "${data['hostels']}", Icons.apartment_rounded, const Color(0xFF0984E3), isDark),
                    _buildStatCard("Pending", "${data['pendingHostels']}", Icons.pending_rounded, const Color(0xFFE17055), isDark),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // 3. QUICK ACTIONS
                Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                const SizedBox(height: 15),
                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                       _buildActionPill(context, "Verify Agents", Icons.verified_user_rounded, Colors.orangeAccent, () {
                         widget.onNavigate?.call(1);
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Switched to Users Tab")));
                       }, isDark),
                       const SizedBox(width: 15),
                       _buildActionPill(context, "Review Listings", Icons.rate_review_rounded, Colors.blueAccent, () {
                         widget.onNavigate?.call(2);
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Switched to Hostels Tab")));
                       }, isDark),
                       const SizedBox(width: 15),
                       _buildActionPill(context, "System Logs", Icons.terminal_rounded, Colors.purpleAccent, () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logs are server-side only.")));
                       }, isDark),
                    ],
                  ),
                ),
                // Adds extra space to prevent bottom navigation interference
                const SizedBox(height: 80), 
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRevenueChartCard(double revenue, List<FlSpot> spots, bool isDark, NumberFormat fmt) {
    double maxY = 100;
    if (spots.isNotEmpty) {
      final maxVal = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      if (maxVal > maxY) maxY = maxVal * 1.25;
    }

    return Container(
      height: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2E2AB7), Color(0xFF5F5ACD)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E2AB7).withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 15),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text("Total Earnings (Net)", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                   const SizedBox(height: 4),
                   FittedBox(
                     fit: BoxFit.scaleDown,
                     child: Text(fmt.format(revenue), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                   ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.show_chart_rounded, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false), // Clean look
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 2, // Less clutter
                      getTitlesWidget: (value, meta) {
                        const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
                        final index = value.toInt();
                        if (index >= 0 && index < 12) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(months[index], style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: 11, minY: 0, maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: Colors.white,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Mini labels for timeline
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("2025", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
            Text("YTD", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
          ])
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF2D3436))),
              ),
              const SizedBox(height: 2),
              Text(title, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionPill(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 5))],
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Flexible(
              child: Text(
                title, 
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 12), 
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
