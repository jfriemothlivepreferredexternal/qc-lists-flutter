import 'package:flutter/material.dart';

typedef TemplateFilterSelectedCallback = void Function(String templateName);

class TemplateFilterSelectionScreen extends StatelessWidget {
  final List<String> templateNames;
  final TemplateFilterSelectedCallback onTemplateSelected;

  const TemplateFilterSelectionScreen({super.key, required this.templateNames, required this.onTemplateSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Template')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Show All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade100,
                  foregroundColor: Colors.blue.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => onTemplateSelected('ALL'),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: templateNames.length,
              itemBuilder: (context, index) {
                final templateName = templateNames[index];
                return Card(
                  child: ListTile(
                    title: Text(templateName),
                    onTap: () => onTemplateSelected(templateName),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
