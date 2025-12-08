import 'package:flutter/material.dart';
import '../models/rider_model.dart';
import '../models/services/admin_service.dart';
import 'main_admin_wrapper.dart';

class RiderManagementScreen extends StatelessWidget {
  const RiderManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("Rider Fleet Management"),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: !isDesktop
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => MainAdminWrapper.openDrawer(context),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRiderDialog(context),
        label: const Text("ADD NEW RIDER"),
        icon: const Icon(Icons.person_add),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Rider>>(
        stream: AdminService().getRidersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final riders = snapshot.data ?? [];

          if (riders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.two_wheeler,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No riders in your fleet yet.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Tap 'Add New Rider' to get started.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 2.2, // Rectangular cards
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: riders.length,
            itemBuilder: (context, index) {
              final rider = riders[index];
              return _buildRiderCard(context, rider);
            },
          );
        },
      ),
    );
  }

  Widget _buildRiderCard(BuildContext context, Rider rider) {
    Color statusColor;
    IconData statusIcon;
    switch (rider.status) {
      case 'available':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'busy':
        statusColor = Colors.orange;
        statusIcon = Icons.delivery_dining;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.offline_bolt;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar with Status Badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.indigo.shade50,
                  child: Text(
                    rider.name.isNotEmpty ? rider.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, size: 18, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    rider.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        rider.phone,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        "${rider.totalDeliveries} Deliveries",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
                  onPressed: () => _showAddRiderDialog(context, rider: rider),
                  tooltip: "Edit Rider",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRiderDialog(BuildContext context, {Rider? rider}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: rider?.name);
    final phoneCtrl = TextEditingController(text: rider?.phone);
    final emailCtrl = TextEditingController(text: rider?.email);
    final passCtrl = TextEditingController();

    String status = rider?.status ?? 'available';
    bool isEditing = rider != null;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEditing ? "Edit Rider" : "Add New Rider"),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: "Full Name",
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: "Phone Number",
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: "Login Email",
                          prefixIcon: Icon(Icons.email),
                        ),
                        validator: (v) =>
                            v!.contains('@') ? null : "Invalid Email",
                        enabled:
                            !isEditing, // Prevent changing email to avoid auth sync issues for this simple version
                      ),
                      if (!isEditing) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passCtrl,
                          decoration: const InputDecoration(
                            labelText: "Create Password",
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                          validator: (v) =>
                              v!.length < 6 ? "Min 6 chars" : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration: const InputDecoration(
                          labelText: "Current Status",
                          prefixIcon: Icon(Icons.traffic),
                        ),
                        items: ['available', 'busy', 'offline'].map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (v) => status = v!,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        setState(() => isLoading = true);

                        try {
                          final newRider = Rider(
                            id:
                                rider?.id ??
                                '', // Empty ID tells service to create new
                            name: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            status: status,
                            latitude:
                                rider?.latitude ??
                                28.6139, // Default/Mock location
                            longitude: rider?.longitude ?? 77.2090,
                            totalDeliveries: rider?.totalDeliveries ?? 0,
                          );

                          await AdminService().saveRider(
                            newRider,
                            password: passCtrl.text.trim(),
                          );

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEditing
                                      ? "Rider Updated"
                                      : "Rider Created & Account Provisioned",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Save Rider"),
              ),
            ],
          );
        },
      ),
    );
  }
}
