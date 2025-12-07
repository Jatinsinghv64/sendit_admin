import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

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
  final _uuid = const Uuid();

  // Category State
  String _name = '';
  File? _pickedImage;
  String? _existingImageUrl;
  int _currentThemeColor = 0xFFFFFFFF;
  late TextEditingController _colorController;

  // Subcategories State
  List<SubCategory> _subCategories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _name = widget.category!.name;
      _existingImageUrl = widget.category!.imageUrl;
      _currentThemeColor = widget.category!.themeColor;
      _subCategories = List.from(widget.category!.subCategories);
    }
    _colorController = TextEditingController(text: _currentThemeColor.toRadixString(16).toUpperCase().padLeft(8, '0'));
  }

  // --- Main Form Submission ---
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImage == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category image is required')));
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final service = Provider.of<AdminService>(context, listen: false);
      final int themeColorInt = int.tryParse(_colorController.text, radix: 16) ?? 0xFFFFFFFF;

      await service.saveCategory(
        id: widget.category?.id,
        name: _name,
        imageFile: _pickedImage,
        existingImageUrl: _existingImageUrl,
        themeColor: themeColorInt,
        subCategories: _subCategories, // Pass the managed subcategories
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Category Saved!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Subcategory Logic ---
  Future<void> _showSubCategoryDialog({int? index}) async {
    final isEdit = index != null;
    final subCat = isEdit ? _subCategories[index] : null;

    final nameCtrl = TextEditingController(text: subCat?.name);
    final offerCtrl = TextEditingController(text: subCat?.offer);

    // Local state for the dialog
    File? dialogImageFile;
    String dialogImageUrl = subCat?.imageUrl ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? "Edit Subcategory" : "Add Subcategory"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Picker
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(source: ImageSource.gallery);
                      if (file != null) {
                        setDialogState(() => dialogImageFile = File(file.path));
                      }
                    },
                    child: Container(
                      height: 100, width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                        image: dialogImageFile != null
                            ? DecorationImage(image: FileImage(dialogImageFile!), fit: BoxFit.cover)
                            : (dialogImageUrl.isNotEmpty
                            ? DecorationImage(image: NetworkImage(dialogImageUrl), fit: BoxFit.cover)
                            : null),
                      ),
                      child: (dialogImageFile == null && dialogImageUrl.isEmpty)
                          ? const Icon(Icons.add_a_photo, color: Colors.grey) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name (e.g. Milk)")),
                  const SizedBox(height: 12),
                  TextField(controller: offerCtrl, decoration: const InputDecoration(labelText: "Offer (e.g. UP TO 50% OFF)")),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;

                  // Handle Image Upload immediately for simplicity or store file to upload later
                  // For robust UX, we upload now to get URL
                  String finalUrl = dialogImageUrl;
                  if (dialogImageFile != null) {
                    // Show global loading or block? Ideally local loading.
                    // For brevity, we assume quick upload or handle in background service
                    final ref = FirebaseStorage.instance.ref().child('subcats/${_uuid.v4()}.jpg');
                    await ref.putFile(dialogImageFile!);
                    finalUrl = await ref.getDownloadURL();
                  }

                  final newSub = SubCategory(
                    name: nameCtrl.text.trim(),
                    imageUrl: finalUrl,
                    offer: offerCtrl.text.trim(),
                  );

                  setState(() {
                    if (isEdit) {
                      _subCategories[index] = newSub;
                    } else {
                      _subCategories.add(newSub);
                    }
                  });
                  Navigator.pop(ctx);
                },
                child: const Text("Save"),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category == null ? "New Category" : "Edit Category")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Main Info"),
              const SizedBox(height: 16),

              // Main Image
              Center(
                child: GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(source: ImageSource.gallery);
                    if (file != null) setState(() => _pickedImage = File(file.path));
                  },
                  child: Container(
                    height: 150, width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _pickedImage != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_pickedImage!, fit: BoxFit.cover))
                        : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_existingImageUrl!, fit: BoxFit.cover))
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image, size: 40, color: Colors.grey), Text("Tap to select image")]),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: "Category Name", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Required" : null,
                onSaved: (v) => _name = v!,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _colorController,
                decoration: InputDecoration(
                    labelText: "Theme Color (ARGB Hex)",
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Color(_currentThemeColor), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey)),
                      width: 24, height: 24,
                    )
                ),
                onChanged: (v) {
                  if (v.length == 8) setState(() => _currentThemeColor = int.tryParse(v, radix: 16) ?? 0xFFFFFFFF);
                },
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("Sub Categories"),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.indigo),
                    onPressed: () => _showSubCategoryDialog(),
                  ),
                ],
              ),

              // Subcategories List
              if (_subCategories.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text("No subcategories added.", style: TextStyle(color: Colors.grey)))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _subCategories.length,
                  separatorBuilder: (_,__) => const Divider(),
                  itemBuilder: (ctx, index) {
                    final sub = _subCategories[index];
                    return ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: Colors.grey.shade200),
                        child: sub.imageUrl.isNotEmpty ? Image.network(sub.imageUrl, fit: BoxFit.cover) : null,
                      ),
                      title: Text(sub.name),
                      subtitle: sub.offer.isNotEmpty
                          ? Text(sub.offer, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showSubCategoryDialog(index: index)),
                          IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => setState(() => _subCategories.removeAt(index))),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text("SAVE CATEGORY"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }
}