import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/providers/search_provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _query = "";
  String _filterType = "All"; // All, Notes, Files, Folders

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySuggested(String text) {
    _searchController.text = text;
    setState(() => _query = text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search notes, PDFs, topics...",
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = "");
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: false,
            ),
            onChanged: (val) => setState(() => _query = val.trim()),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Notes', 'Files', 'Folders'].map((type) {
                  final isSel = _filterType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSel,
                      label: Text(type),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? Colors.white : AppColors.textPrimary,
                      ),
                      backgroundColor: AppColors.surfaceElevated,
                      selectedColor: AppColors.primary,
                      side: BorderSide(color: isSel ? AppColors.primary : AppColors.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (_) => setState(() => _filterType = type),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Search Results or Empty State
          Expanded(
            child: _query.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Quick Search Suggestions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _suggestChip('ACID Properties'),
                            _suggestChip('Deadlock'),
                            _suggestChip('TCP vs UDP'),
                            _suggestChip('Operating Systems'),
                            _suggestChip('DBMS'),
                            _suggestChip('Computer Networks'),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: const Icon(Icons.saved_search_rounded, size: 48, color: AppColors.primaryLight),
                              ),
                              const SizedBox(height: 16),
                              const Text("Instant Vault Search", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              const Text(
                                "Search across all your lecture notes, uploaded PDFs, and subject folders.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : searchAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text("Error: $err")),
                    data: (results) {
                      final filtered = results.where((item) {
                        final String type = item.containsKey('content') ? 'Notes' : (item.containsKey('storage_path') ? 'Files' : 'Folders');
                        if (_filterType == 'All') return true;
                        return _filterType == type;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_rounded, size: 56, color: AppColors.textMuted),
                              const SizedBox(height: 16),
                              Text("No results for '$_query'", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              const Text("Try searching with broader terms or keywords", style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final String type = item.containsKey('content') ? 'Note' : (item.containsKey('storage_path') ? 'PDF' : 'Folder');
                          final String name = item['title'] ?? item['name'] ?? 'Untitled';
                          
                          final IconData icon = type == 'Note'
                              ? Icons.note_alt_outlined
                              : (type == 'PDF' ? Icons.picture_as_pdf_outlined : Icons.folder_outlined);
                          final Color color = type == 'Note'
                              ? AppColors.primary
                              : (type == 'PDF' ? AppColors.cyan : AppColors.amber);

                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: ListTile(
                              onTap: () {
                                if (type == 'Note') context.push('/notes/${item['id']}');
                                if (type == 'PDF') context.push('/files/${item['id']}');
                                if (type == 'Folder') context.push('/folder/${item['id']}');
                              },
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.15),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                              subtitle: Text(type, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _suggestChip(String label) {
    return ActionChip(
      backgroundColor: AppColors.surfaceElevated,
      side: const BorderSide(color: AppColors.cardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      label: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
      onPressed: () => _applySuggested(label),
    );
  }
}

