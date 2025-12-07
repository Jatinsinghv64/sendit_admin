import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../models/services/admin_service.dart';

class AddEditProductScreen extends StatefulWidget {
  final String? productId; // Pass ID to force fresh fetch
  const AddEditProductScreen({super.key, this.productId});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final AdminService _service = AdminService();

  Product? _product;
  bool _isLoading = true;

  // Form Fields
  String _name = '';
  String _sku = '';
  double _price = 0.0;
  int _qty = 0;
  String _unit = 'units';
  String _categoryId = '';
  String _description = ''; // Added description field
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.productId != null) {
      _product = await _service.getProductById(widget.productId!);
      if (_product != null) {
        _name = _product!.name;
        _sku = _product!.sku;
        _price = _product!.price;
        // FIX: Use the correct getter 'stockQty' from the Product model
        _qty = _product!.stockQty;
        _description = _product!.description;
        _categoryId = _product!.categoryId;
        // Note: 'unit' is not in the top-level Product model provided earlier,
        // assuming it's standardized or managed elsewhere.
        // If needed, add 'unit' to your Product model.
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final newProduct = Product(
        id: widget.productId ?? '',
        name: _name,
        description: _description,
        price: _price,
        categoryId: _categoryId,
        // FIX: Use 'imageUrl' as defined in the Product constructor.
        // If _product is null, pass empty string.
        imageUrl: _product?.imageUrl ?? '',
        // FIX: Pass stockQty using the named parameter 'stockQty'
        stockQty: _qty,
        sku: _sku,
        isActive: true,
      );

      await _service.saveProduct(product: newProduct, imageFile: _imageFile);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(widget.productId == null ? "New Product" : "Edit Product")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150, width: 150,
                  color: Colors.grey[200],
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : (_product?.imageUrl.isNotEmpty == true
                  // FIX: Use alias getter 'thumbnailUrl' or 'imageUrl'
                      ? Image.network(_product!.imageUrl, fit: BoxFit.cover)
                      : const Icon(Icons.add_a_photo)),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: "Name"),
                onSaved: (v) => _name = v!,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                initialValue: _sku,
                decoration: const InputDecoration(labelText: "SKU / Barcode"),
                onSaved: (v) => _sku = v!,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _price.toString(),
                      decoration: const InputDecoration(labelText: "Price"),
                      keyboardType: TextInputType.number,
                      onSaved: (v) => _price = double.parse(v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: _qty.toString(),
                      decoration: const InputDecoration(labelText: "Stock"),
                      keyboardType: TextInputType.number,
                      onSaved: (v) => _qty = int.parse(v!),
                    ),
                  ),
                ],
              ),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: "Description"),
                onSaved: (v) => _description = v!,
                maxLines: 3,
              ),
              // Add Category Dropdown here using AdminService().getCategories()
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _save, child: const Text("Save"))
            ],
          ),
        ),
      ),
    );
  }
}