import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../models/category.dart';
import '../models/services/admin_service.dart';
import 'add_edit_category_screen.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = Provider.of<AdminService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Category Management')),
      body: StreamBuilder<List<Category>>(
        stream: adminService.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No categories found.'));
          }

          final categories = snapshot.data!;
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                leading: category.imageUrl.isNotEmpty
                    ? Image.network(category.imageUrl, width: 40, height: 40, fit: BoxFit.cover)
                    : const Icon(Icons.folder, size: 40, color: Colors.indigo),
                title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => AddEditCategoryScreen(category: category)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddEditCategoryScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}