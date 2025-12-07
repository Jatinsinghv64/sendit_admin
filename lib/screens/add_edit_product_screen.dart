import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category.dart';
import '../models/services/admin_service.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final Category? category;
  const AddEditCategoryScreen({super.key, this.category});

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _name = widget.category?.name ?? '';
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      if (widget.category == null) {
        await AdminService().createCategory(_name, _imageFile);
      } else {
        await AdminService().updateCategory(
            widget.category!.id,
            _name,
            _imageFile,
            widget.category!.imageUrl
        );
      }
      if (mounted) Navigator.pop(context);
    } catch(e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category == null ? "New Category" : "Edit Category")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : (widget.category?.imageUrl.isNotEmpty == true
                      ? NetworkImage(widget.category!.imageUrl) as ImageProvider
                      : null),
                  child: (_imageFile == null && (widget.category?.imageUrl.isEmpty ?? true))
                      ? const Icon(Icons.camera_alt, size: 30)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: "Category Name", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? "Required" : null,
                onSaved: (val) => _name = val!,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _save,
                    child: const Text("Save Category")
                ),
              ),
              if (widget.category != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    // Add delete logic here
                    await AdminService().deleteCategory(widget.category!.id);
                    if (mounted) Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Delete Category"),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}