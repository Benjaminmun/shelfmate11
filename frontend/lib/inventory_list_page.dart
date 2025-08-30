import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory_item_model.dart';
import 'inventory_service.dart';
import 'inventory_edit_page.dart';

class InventoryListPage extends StatefulWidget {
  final String householdId;
  final String householdName;

  const InventoryListPage({Key? key, required this.householdId, required this.householdName}) : super(key: key);

  @override
  _InventoryListPageState createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  final InventoryService _inventoryService = InventoryService();
  final Color primaryColor = Color(0xFF2D5D7C);
  final Color accentColor = Color(0xFF4CAF50);
  final Color backgroundColor = Color(0xFFE2E6E0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('${widget.householdName} Inventory'),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InventoryEditPage(
                    householdId: widget.householdId,
                    householdName: widget.householdName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _inventoryService.getItemsStream(widget.householdId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error loading inventory',
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            );
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.black38),
                  SizedBox(height: 16),
                  Text(
                    'No inventory items yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black54),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add your first item to get started',
                    style: TextStyle(fontSize: 16, color: Colors.black38),
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InventoryEditPage(
                            householdId: widget.householdId,
                            householdName: widget.householdName,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: Text(
                      'Add First Item',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var item = InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              
              return _buildInventoryCard(item, context);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InventoryEditPage(
                householdId: widget.householdId,
                householdName: widget.householdName,
              ),
            ),
          );
        },
        backgroundColor: accentColor,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item, BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.inventory_2_outlined, color: primaryColor, size: 30),
        ),
        title: Text(
          item.name,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('Category: ${item.category}'),
            Text('Quantity: ${item.quantity}'),
            Text('Price: \$${item.price.toStringAsFixed(2)}'),
            if (item.expiryDate != null)
              Text('Expiry: ${_formatDate(item.expiryDate!)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: primaryColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InventoryEditPage(
                      householdId: widget.householdId,
                      householdName: widget.householdName,
                      item: item,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _showDeleteDialog(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(InventoryItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Item'),
          content: Text('Are you sure you want to delete ${item.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _inventoryService.deleteItem(widget.householdId, item.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.name} deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting item: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}