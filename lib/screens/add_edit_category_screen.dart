import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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
  String _name = '';
  File? _pickedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _name = widget.category!.name;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if an image is provided on creation or if an image already exists on edit
    if (_pickedImage == null && (widget.category == null || widget.category!.imageUrl.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category image.')));
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final adminService = Provider.of<AdminService>(context, listen: false);

    try {
      await adminService.saveCategory(
        name: _name,
        imageFile: _pickedImage,
        id: widget.category?.id,
        existingImageUrl: widget.category?.imageUrl,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category ${_name} saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save category: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Category' : 'Add New Category')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Display
              Center(child: _buildImageWidget()),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: Text(isEditing ? 'Change Image' : 'Select Image'),
                ),
              ),
              const SizedBox(height: 20),

              // Category Name
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter a name.' : null,
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditing ? 'Update Category' : 'Add Category', style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (_pickedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.file(_pickedImage!, height: 100, width: 100, fit: BoxFit.cover),
      );
    } else if (widget.category?.imageUrl.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.network(widget.category!.imageUrl, height: 100, width: 100, fit: BoxFit.cover),
      );
    } else {
      return Container(
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: const Icon(Icons.photo_library, size: 40, color: Colors.grey),
      );
    }
  }
}