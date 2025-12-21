import 'package:flutter/material.dart';
// import '../models/checklist_models.dart';
import '../services/storage_service.dart';
import '../services/property_filter.dart';
import '../widgets/app_menu.dart';
// import 'checklist_screen.dart';

typedef TemplateSelectedCallback = void Function(dynamic selectionData);

class TemplateSelectionScreen extends StatefulWidget {
  final List<String> templateNames;
  final TemplateSelectedCallback onTemplateSelected;
  const TemplateSelectionScreen({super.key, required this.templateNames, required this.onTemplateSelected});

  @override
  State<TemplateSelectionScreen> createState() => _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends State<TemplateSelectionScreen> {
  String? _selectedBuilding;
  String? _selectedUnit;
  // Removed unused _templates field
  bool _isLoading = true;

  // Generate building options (1-12)
  List<String> get _buildingOptions => 
      List.generate(12, (index) => (index + 1).toString());

  // Generate unit options organized by towers
  List<String> get _unitOptions {
    List<String> units = [];
    
    // Tower 1: 101-104, 201-204, 301-304
    // Tower 2: 105-108, 205-208, 305-308  
    // Tower 3: 109-112, 209-212, 309-312
    
    for (int tower = 1; tower <= 3; tower++) {
      // Add all units for this tower across all floors
      for (int floor = 1; floor <= 3; floor++) {
        int startUnit = (tower - 1) * 4 + 1; // Tower 1: 1, Tower 2: 5, Tower 3: 9
        for (int unitOffset = 0; unitOffset < 4; unitOffset++) {
          int unitNum = startUnit + unitOffset;
          String unitNumber = '${floor}${unitNum.toString().padLeft(2, '0')}';
          units.add(unitNumber);
        }
      }
    }
    
    return units;
  }

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    // No controllers to dispose anymore
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    await StorageService.loadTemplates();
    setState(() {
      _isLoading = false;
    });
  }

  // Removed unused _createChecklistFromTemplate method

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('QC Lists'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () => AppMenu.show(context, onTemplateEdited: _loadTemplates),
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select Template and Location:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Property display
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: Colors.blue.shade100,
              child: Text(
                'Creating for: ${PropertyFilter.selectedProperty ?? 'Unknown Property'}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedBuilding,
                    decoration: const InputDecoration(
                      labelText: 'Building #',
                      border: OutlineInputBorder(),
                    ),
                    items: _buildingOptions.map((building) {
                      return DropdownMenuItem<String>(
                        value: building,
                        child: Text('Building $building'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBuilding = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit #',
                      border: OutlineInputBorder(),
                    ),
                    items: _unitOptions.map((unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text('Unit $unit'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUnit = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose Template:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: widget.templateNames.length,
                      itemBuilder: (context, index) {
                        final templateName = widget.templateNames[index];
                        final canSelect = _selectedBuilding != null && _selectedUnit != null;
                        return Card(
                          color: canSelect ? null : Colors.grey[200],
                          child: InkWell(
                            onTap: canSelect ? () {
                              final selectionData = {
                                'templateName': templateName,
                                'building': _selectedBuilding!,
                                'unit': _selectedUnit!,
                              };
                              widget.onTemplateSelected(selectionData);
                            } : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    templateName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: canSelect ? Theme.of(context).primaryColor : Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (canSelect)
                                    const Text(
                                      'Tap to select',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}