import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/services/admin_service.dart';


class AddEditProductScreen extends StatefulWidget {
  final Product? product; // null for add, non-null for edit
  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _description = '';
  double _price = 0.0;
  int _stockQty = 0;
  String _stockUnit = 'units';
  String _categoryId = 'general'; // Simplified: use a generic category ID
  String _sku = '';
  File? _pickedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _name = widget.product!.name;
      _description = widget.product!.description;
      _price = widget.product!.price;
      _stockQty = widget.product!.stock['availableQty'] ?? 0;
      _stockUnit = widget.product!.stock['unit'] ?? 'units';
      _categoryId = widget.product!.categoryId;
      _sku = widget.product!.sku;
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
    if (_pickedImage == null && widget.product == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image.')));
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final adminService = Provider.of<AdminService>(context, listen: false);

    final newProduct = Product(
      id: widget.product?.id ?? '',
      name: _name,
      description: _description,
      price: _price,
      categoryId: _categoryId,
      thumbnailUrl: widget.product?.thumbnailUrl ?? '',
      stock: {'availableQty': _stockQty, 'unit': _stockUnit},
      sku: _sku,
    );

    try {
      await adminService.saveProduct(
        product: newProduct,
        imageFile: _pickedImage,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Product ${_name} saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save product: $e')),
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
    final isEditing = widget.product != null;

    // Simplified list of units - in a real app this would be dynamically fetched
    const List<String> units = ['units', 'kg', 'g', 'ml', 'liters', 'packets'];

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Product' : 'Add New Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Image Picker
              Center(child: _buildImageWidget()),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(isEditing ? 'Change Image' : 'Select Image')
                ),
              ),
              const SizedBox(height: 20),

              // Product Name
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter a name.' : null,
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 15),

              // SKU/Barcode
              TextFormField(
                initialValue: _sku,
                decoration: const InputDecoration(labelText: 'SKU / Barcode', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter a SKU/Barcode.' : null,
                onSaved: (value) => _sku = value!,
              ),
              const SizedBox(height: 15),

              // Price
              TextFormField(
                initialValue: _price.toString(),
                decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value!.isEmpty) return 'Please enter a price.';
                  if (double.tryParse(value) == null) return 'Please enter a valid number.';
                  return null;
                },
                onSaved: (value) => _price = double.parse(value!),
              ),
              const SizedBox(height: 15),

              // Stock and Unit Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: _stockQty.toString(),
                      decoration: const InputDecoration(labelText: 'Stock Quantity', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value!.isEmpty) return 'Qty required.';
                        if (int.tryParse(value) == null) return 'Valid number required.';
                        return null;
                      },
                      onSaved: (value) => _stockQty = int.parse(value!),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
                      value: _stockUnit,
                      items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _stockUnit = newValue);
                        }
                      },
                      onSaved: (value) => _stockUnit = value!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Description
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                onSaved: (value) => _description = value ?? '',
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditing ? 'Update Product' : 'Add Product', style: const TextStyle(fontSize: 18)),
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
        child: Image.file(_pickedImage!, height: 150, width: 150, fit: BoxFit.cover),
      );
    } else if (widget.product?.thumbnailUrl.isNotEmpty == true) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.network(widget.product!.thumbnailUrl, height: 150, width: 150, fit: BoxFit.cover),
      );
    } else {
      return Container(
        height: 150,
        width: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: const Icon(Icons.photo_library, size: 50, color: Colors.grey),
      );
    }
  }
}