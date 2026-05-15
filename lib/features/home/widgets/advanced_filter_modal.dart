import 'package:flutter/material.dart';

class AdvancedFilterModal extends StatefulWidget {
  final Function(Map<String, dynamic> filters) onApply;
  final Map<String, dynamic> currentFilters;

  const AdvancedFilterModal({
    super.key,
    required this.onApply,
    required this.currentFilters,
  });

  @override
  State<AdvancedFilterModal> createState() => _AdvancedFilterModalState();
}

class _AdvancedFilterModalState extends State<AdvancedFilterModal> {
  late RangeValues _priceRange;
  late List<String> _selectedAmenities;
  late String _sortOrder;

  final double _minPrice = 0;
  final double _maxPrice = 10000;

  final List<String> _amenities = [
    "WiFi", "AC", "Fridge", "Kitchen", "Study Room", "Gym", "Security", "Generator"
  ];

  @override
  void initState() {
    super.initState();
    _priceRange = widget.currentFilters['priceRange'] ?? const RangeValues(0, 5000);
    _selectedAmenities = List<String>.from(widget.currentFilters['amenities'] ?? []);
    _sortOrder = widget.currentFilters['sort'] ?? 'relevance';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Filter Stays", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Price Range
          const Text("Price Range (GHS / Year)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          RangeSlider(
            values: _priceRange,
            min: _minPrice,
            max: _maxPrice,
            divisions: 20,
            labels: RangeLabels(
              _priceRange.start.round().toString(),
              _priceRange.end.round().toString(),
            ),
            onChanged: (values) => setState(() => _priceRange = values),
            activeColor: Theme.of(context).primaryColor,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("GHS ${_priceRange.start.round()}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("GHS ${_priceRange.end.round()}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),

          // 2. Amenities
          const Text("Amenities", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _amenities.map((amenity) {
              final isSelected = _selectedAmenities.contains(amenity);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedAmenities.remove(amenity);
                    } else {
                      _selectedAmenities.add(amenity);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.3)),
                  ),
                  child: Text(
                    amenity,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),

          // 3. Apply Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply({
                  'priceRange': _priceRange,
                  'amenities': _selectedAmenities,
                  'sort': _sortOrder,
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Show Results", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

