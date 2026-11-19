import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../storage/local_jianpu_document.dart';

class JianpuDocumentDrawer extends StatelessWidget {
  const JianpuDocumentDrawer({
    super.key,
    required this.documents,
    required this.currentDocumentId,
    required this.isLoading,
    required this.onCreate,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.formatDate,
  });

  final List<LocalJianpuDocument> documents;
  final String? currentDocumentId;
  final bool isLoading;
  final VoidCallback onCreate;
  final Future<void> Function(LocalJianpuDocument) onOpen;
  final ValueChanged<LocalJianpuDocument> onRename;
  final ValueChanged<LocalJianpuDocument> onDelete;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "JP Typewriter",
              style: GoogleFonts.lxgwWenKaiMonoTc(fontSize: 22),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: isLoading ? null : onCreate,
                  label: const Text("New"),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final doc = documents[index];
                      final selected = doc.id == currentDocumentId;
                      return ListTile(
                        selected: selected,
                        title: Text(
                          doc.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(formatDate(doc.updatedAt)),
                        onTap: () => onOpen(doc),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Document actions',
                          onSelected: (action) {
                            if (action == 'rename') onRename(doc);
                            if (action == 'delete') onDelete(doc);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
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
