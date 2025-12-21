import 'package:flutter/material.dart';
import '../models/checklist_models.dart';
import '../services/storage_service.dart';
import '../screens/issues_dashboard_screen.dart';
import '../screens/template_edit_screen.dart';

class AppMenu {
  static void show(BuildContext context, {VoidCallback? onTemplateEdited}) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.assignment_late),
              title: const Text('Issues Dashboard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const IssuesDashboardScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Templates'),
              onTap: () {
                Navigator.pop(context);
                _editTemplates(context, onTemplateEdited);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAbout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _editTemplates(BuildContext context, VoidCallback? onTemplateEdited) async {
    final TextEditingController passwordController = TextEditingController();
    final isAuthorized = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter password to edit templates:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final isCorrect = value == 'drum';
                Navigator.pop(context, isCorrect);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final isCorrect = passwordController.text == 'drum';
              Navigator.pop(context, isCorrect);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (isAuthorized == true && context.mounted) {
      final templates = await StorageService.loadTemplates();
      
      if (!context.mounted) return;
      
      final selectedTemplateId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Template to Edit'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final templateId = templates.keys.elementAt(index);
                final template = templates[templateId]!;
                return ListTile(
                  title: Text(template.name),
                  subtitle: Text('${template.items.length} items'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => Navigator.pop(context, templateId),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedTemplateId != null && context.mounted) {
        final result = await Navigator.push<QCTemplate>(
          context,
          MaterialPageRoute(
            builder: (context) => TemplateEditScreen(
              template: templates[selectedTemplateId]!,
            ),
          ),
        );

        if (result != null) {
          templates[result.id] = result;
          await StorageService.saveTemplates(templates);
          onTemplateEdited?.call();
        }
      }
    }
  }

  static void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About QC Lists'),
        content: const Text('A simple app for creating and managing quality control checklists.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
