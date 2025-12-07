import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/services/admin_service.dart';
import 'add_edit_category_screen.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Categories")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditCategoryScreen())
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Category>>(
        stream: AdminService().getCategories(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cats = snapshot.data ?? [];

          if (cats.isEmpty) {
            return const Center(child: Text("No categories found."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: cats.length,
            separatorBuilder: (_,__) => const Divider(),
            itemBuilder: (context, index) {
              final c = cats[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: c.imageUrl.isNotEmpty ? NetworkImage(c.imageUrl) : null,
                  child: c.imageUrl.isEmpty ? const Icon(Icons.category) : null,
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddEditCategoryScreen(category: c))
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}