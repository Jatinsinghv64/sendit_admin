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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditCategoryScreen())),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Category>>(
        stream: AdminService().getCategories(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final cats = snapshot.data!;
          return ListView.separated(
            itemCount: cats.length,
            separatorBuilder: (_,__) => const Divider(),
            itemBuilder: (context, index) {
              final c = cats[index];
              return ListTile(
                leading: CircleAvatar(backgroundImage: c.imageUrl.isNotEmpty ? NetworkImage(c.imageUrl) : null),
                title: Text(c.name),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCategoryScreen(category: c))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}