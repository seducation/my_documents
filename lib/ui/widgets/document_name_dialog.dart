import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DocumentNameDialog extends StatefulWidget {
  final String title;
  final String label;
  final String? initialValue;

  const DocumentNameDialog({
    super.key,
    this.title = 'New Document',
    this.label = 'Document Name',
    this.initialValue,
  });

  @override
  State<DocumentNameDialog> createState() => _DocumentNameDialogState();
}

class _DocumentNameDialogState extends State<DocumentNameDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller = TextEditingController(text: widget.initialValue);
    } else {
      // Pre-fill with default name if creating new document, else empty for folders typically or handle in parent
      // Logic: If label 'Document Name' and no initial value, use timestamp.
      // If 'New Folder Name' (or just specific title check), maybe 'New Folder'.

      String defaultText = '';
      if (widget.label == 'Document Name') {
        final timestamp = DateFormat('MMM d, y h:mm a').format(DateTime.now());
        defaultText = 'Document - $timestamp';
      } else if (widget.label == 'Folder Name') {
        defaultText = 'New Folder';
      }

      _controller = TextEditingController(text: defaultText);
    }

    // Select all text for easy replacement
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final title = _controller.text.trim();

    if (title.isEmpty) {
      setState(() {
        _errorText = 'Please enter a name';
      });
      return;
    }

    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _onSubmit(),
        onChanged: (_) {
          if (_errorText != null) {
            setState(() {
              _errorText = null;
            });
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _onSubmit,
          child: Text(widget.initialValue != null ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
