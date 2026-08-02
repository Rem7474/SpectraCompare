import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'library_controller.dart';
import 'measurement_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothèque'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: library.load),
        ],
      ),
      body: SafeArea(
        child: library.isLoading
            ? const Center(child: CircularProgressIndicator())
            : library.measurements.isEmpty
                ? const Center(child: Text('Aucune mesure enregistrée.'))
                : ListView.builder(
                    itemCount: library.measurements.length,
                    itemBuilder: (context, index) {
                      final m = library.measurements[index];
                      return ListTile(
                        title: Text(m.displayName),
                        subtitle: Text('${m.signalConfig.type.name} — ${m.createdAt}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => library.delete(m.id!),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => MeasurementDetailScreen(measurement: m)),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
