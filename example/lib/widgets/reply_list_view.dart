import 'package:flutter/material.dart';

import '../models/data.dart' as data;
import '../models/models.dart';
import 'email_widget.dart';

class ReplyListView extends StatefulWidget {
  const ReplyListView({super.key});

  @override
  State<ReplyListView> createState() => _ReplyListViewState();
}

class _ReplyListViewState extends State<ReplyListView> {
  late List<Email> _replies;

  @override
  void initState() {
    super.initState();
    _replies = List.of(data.replies);
  }

  void _removeAt(int index) {
    setState(() {
      _replies.removeAt(index);
    });
  }

  void _restoreReplies() {
    setState(() {
      _replies = List.of(data.replies);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_replies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No hay datos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _restoreReplies,
                child: const Text('Restaurar'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ListView(
        children: [
          const SizedBox(height: 8),
          ...List.generate(_replies.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: EmailWidget(
                email: _replies[index],
                isPreview: false,
                isThreaded: true,
                showHeadline: index == 0,
                onDelete: () => _removeAt(index),
              ),
            );
          }),
        ],
      ),
    );
  }
}
