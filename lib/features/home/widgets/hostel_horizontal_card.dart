import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/features/home/hostel_details_page.dart';
import 'package:stayhub/core/image_utils.dart';

class HostelHorizontalCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const HostelHorizontalCard({super.key, required this.data});

  String _getSecureUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> rooms = data['rooms'] ?? [];
    double minPrice = 0;
    double maxPrice = 0;
    int totalSlots = 0;

    if (rooms.isNotEmpty) {
      final prices = rooms.map((r) => ((r['price'] as num? ?? 0).toDouble() * 1.10)).toList();
      prices.sort();
      minPrice = prices.first;
      maxPrice = prices.last;
      for (var r in rooms) {
        totalSlots += (r['available'] as num? ?? 0).toInt();
      }
    } else {
      final basePrice = (data['price'] is num) ? (data['price'] as num).toDouble() : (double.tryParse(data['price']?.toString() ?? '0') ?? 0.0);
      minPrice = basePrice * 1.10;
      maxPrice = minPrice;
      
      final rawCap = data['capacity'];
      if (rawCap is num) {
        totalSlots = rawCap.toInt();
      } else {
        totalSlots = int.tryParse(rawCap?.toString() ?? '0') ?? 0;
      }
    }

    final bool isFull = (data['isFull'] ?? false) || totalSlots <= 0;
    // ... (rest of the build method init)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    // On large screens, card width should not scale infinitely.
    final double cardWidth = (screenWidth > 600) ? 350.0 : (screenWidth * 0.75);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: data))),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 16, bottom: 8, top: 4), 
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24), 
          boxShadow: [
             BoxShadow(
               color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.15),
               blurRadius: 12, 
               offset: const Offset(0, 6)
             )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Hero( 
                    tag: 'hostel_image_${data['id']}',
                    child: (data['image'] == null || data['image'].toString().isEmpty) 
                      ? Container(height: 165, width: double.infinity, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey))
                      : CachedNetworkImage(
                          imageUrl: ImageUtils.getSecureUrl(data['image']),
                          height: 165, 
                          width: double.infinity,
                          fit: BoxFit.cover,
                          memCacheWidth: 600, // Constrain memory usage
                          placeholder: (_,__) => Container(height: 165, color: Colors.grey[200]),
                          errorWidget: (_,__,___) => Container(height: 165, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                  ),
                ),
                // ... (rest of stack)
                
                // Overlay Gradient
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      )
                    ),
                  ),
                ),

                // Rating Pill (Top Left)
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5)
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "${data['rating'] ?? '4.5'}", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white)
                        ),
                      ],
                    ),
                  ),
                ),

                // Status Badge (Top Right)
                if (isFull)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                      child: const Text("FULL", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  )
                else 
                   Positioned( 
                    top: 8, right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      radius: 16,
                      child: Icon(Icons.favorite_border_rounded, size: 18, color: Colors.grey[600]),
                    )
                   ),

                // Price Tag (Bottom Right on Image for "Creative" look)
                Positioned(
                  bottom: 12, right: 12,
                  child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                     decoration: BoxDecoration(
                       color: Theme.of(context).primaryColor,
                       borderRadius: BorderRadius.circular(12),
                       boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
                     ),
                     child: Text(
                        minPrice == maxPrice 
                          ? "GHS ${minPrice.toStringAsFixed(0)}" 
                          : "GHS ${minPrice.toStringAsFixed(0)}+", 
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12),
                      ),
                  ),
                ),
              ],
            ),
            
            // Details Section
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? '', 
                    style: TextStyle(
                      fontWeight: FontWeight.w700, 
                      fontSize: 14,
                      height: 1.1,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 11, color: Theme.of(context).primaryColor.withOpacity(0.7)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          data['location'] ?? 'Unknown', 
                          style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w500), 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis
                        )
                      ),
                      Text(
                        isFull ? "FULL" : "$totalSlots left",
                        style: TextStyle(fontSize: 9, color: isFull ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ]
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAmenityIcon(IconData icon, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 10, color: Colors.grey),
    );
  }
}

