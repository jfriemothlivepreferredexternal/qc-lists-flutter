import 'package:flutter/material.dart';
import '../models/checklist_models.dart';

class TemplateEditScreen extends StatefulWidget {
  final QCTemplate template;

  const TemplateEditScreen({super.key, required this.template});

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  late List<TextEditingController> _controllers;
  final TextEditingController _pasteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controllers = widget.template.items
        .map((item) => TextEditingController(text: item))
        .toList();
    
    // Populate paste area with current template items
    _pasteController.text = widget.template.items.join('\n');
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _pasteController.dispose();
    super.dispose();
  }

  void _parseFromPaste() {
    final pastedText = _pasteController.text.trim();
    if (pastedText.isEmpty) return;

    // Split by newlines and filter out empty lines
    final lines = pastedText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) return;

    // Dispose old controllers
    for (var controller in _controllers) {
      controller.dispose();
    }

    // Create new controllers with parsed items
    setState(() {
      _controllers = lines
          .map((line) => TextEditingController(text: line))
          .toList();
    });

    // Sync the paste area with the new items
    _syncPasteArea();
  }

  void _syncPasteArea() {
    // Update paste area to reflect current individual items
    final currentItems = _controllers.map((c) => c.text).toList();
    _pasteController.text = currentItems.join('\n');
  }

  void _addItem() {
    setState(() {
      _controllers.add(TextEditingController());
    });
    _syncPasteArea();
  }

  void _removeItem(int index) {
    if (_controllers.length <= 1) return; // Keep at least one item
    
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
    _syncPasteArea();
  }

  void _saveTemplate() {
    final updatedItems = _controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    
    if (updatedItems.isEmpty) {
      // Show error if no items
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template must have at least one item')),
      );
      return;
    }

    final updatedTemplate = QCTemplate(
      id: widget.template.id,
      name: widget.template.name,
      items: updatedItems,
    );
    Navigator.pop(context, updatedTemplate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Template ${widget.template.id}'),
        actions: [
          TextButton(
            onPressed: _saveTemplate,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Paste area section
            const Text(
              'Paste Your List:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pasteController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Current template items shown here. Edit directly or paste new list (one per line)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _parseFromPaste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Parse List from Above'),
            ),
            const SizedBox(height: 24),
            
            // Individual items section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Individual Items:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_circle),
                  tooltip: 'Add Item',
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Scrollable items list
            Expanded(
              child: ListView.builder(
                itemCount: _controllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controllers[index],
                            decoration: InputDecoration(
                              labelText: 'Item ${index + 1}',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => _syncPasteArea(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _controllers.length > 1 
                              ? () => _removeItem(index)
                              : null,
                          icon: const Icon(Icons.remove_circle),
                          tooltip: 'Remove Item',
                          color: _controllers.length > 1 
                              ? Colors.red 
                              : Colors.grey[400],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveTemplate,
              child: const Text('Save Template'),
            ),
          ],
        ),
      ),
    );
  }
}