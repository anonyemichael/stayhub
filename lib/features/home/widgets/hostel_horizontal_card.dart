import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stayhub/features/home/hostel_details_page.dart';

class HostelHorizontalCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const HostelHorizontalCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final bool isFull = (data['isFull'] ?? false) || (data['capacity'] ?? 0) == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth * 0.60; // Responsive width

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HostelDetailsPage(hostel: data))),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 16, bottom: 8, top: 4), // Added top margin for shadow
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24), // Softer corners
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
                  child: Hero( // Nice animation
                    tag: 'hostel_image_${data['id']}',
                    child: CachedNetworkImage(
                      imageUrl: data['image'] ?? '',
                      height: 145, // Reduced to safe height
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_,__) => Container(color: Colors.grey[200]),
                      errorWidget: (_,__,___) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
                
                // Overlay Gradient for text readability if needed (optional, but good for "Price on Image")
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
                      color: Colors.black.withOpacity(0.6), // Consistent dark pill looks premium
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
                   Positioned( // "Like" button if not full
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
                      "GHS ${data['price'] ?? '0'}", 
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            // Details Section
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? '', 
                    style: TextStyle(
                      fontWeight: FontWeight.w700, 
                      fontSize: 16,
                      height: 1.2,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: Theme.of(context).primaryColor.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['location'] ?? 'Unknown', 
                          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w500), 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis
                        )
                      )
                    ]
                  ),
                  const SizedBox(height: 8),
                  // Amenities row (Optional creative touch)
                  Row(
                    children: [
                        _buildMiniAmenityIcon(Icons.wifi, context),
                        const SizedBox(width: 6),
                        _buildMiniAmenityIcon(Icons.bolt, context),
                        const SizedBox(width: 6),
                        Text("+ more", style: TextStyle(fontSize: 10, color: Colors.grey[500]))
                    ],
                  )
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
