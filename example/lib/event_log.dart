import 'package:flutter/material.dart';

/// Displays a scrollable log of SDK event strings with an optional clear
/// button. Entries are expected to be newest-first (index 0 is newest).
class EventLogPanel extends StatelessWidget {
  const EventLogPanel({super.key, required this.entries, this.onClear});

  final List<String> entries;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(child: Text('Events (${entries.length})')),
                Visibility(
                  visible: onClear != null,
                  child: IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: onClear,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: entries.isEmpty
                ? const Center(child: Text('No events yet'))
                : ListView.builder(
                    reverse: false,
                    itemCount: entries.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Text(
                        entries[i],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
