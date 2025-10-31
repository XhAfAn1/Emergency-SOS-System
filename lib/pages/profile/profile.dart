import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../Class Models/emergency contact.dart';
import '../../Class Models/user.dart';

class profile extends StatefulWidget {
  final uid;
  const profile({super.key, this.uid});

  @override
  State<profile> createState() => _profileState();
}

class _profileState extends State<profile> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactRelationshipController = TextEditingController();
  final _msgController = TextEditingController();

  bool isEditing = false;
  final _formKey = GlobalKey<FormState>();
  List<EmergencyContact> emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    [_nameController, _phoneController, _addressController,
      _contactNameController, _contactPhoneController, _contactRelationshipController,_msgController]
        .forEach((controller) => controller.dispose());
    super.dispose();
  }

  _loadContacts() async {
    try {
      final doc = await FirebaseFirestore.instance.collection("Users").doc(widget.uid).get();
      if (doc.exists && doc.data()!.containsKey('emergencyContacts')) {
        setState(() {
          emergencyContacts = (doc.data()!['emergencyContacts'] as List)
              .map<EmergencyContact>((json) => EmergencyContact.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('Error loading contacts: $e');
    }
  }

  _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance.collection("Users").doc(widget.uid).update({
          'name': _nameController.text,
          'phoneNumber': _phoneController.text,
          'address': _addressController.text,
          'msg': _msgController.text,
          'emergencyContacts': emergencyContacts.map((c) => c.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() => isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Profile updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  _showContactDialog([int? index]) {
    final contact = index != null ? emergencyContacts[index] : null;
    _contactNameController.text = contact?.name ?? '';
    _contactPhoneController.text = contact?.phoneNumber ?? '';
    _contactRelationshipController.text = contact?.relationship ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '${index != null ? 'Edit' : 'Add'} Emergency Contact',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _contactNameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _contactRelationshipController,
              decoration: InputDecoration(
                labelText: 'Relationship',
                hintText: 'e.g., Mother, Father, Spouse',
                prefixIcon: Icon(Icons.people_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_contactNameController.text.trim().isEmpty ||
                  _contactPhoneController.text.trim().isEmpty ||
                  _contactRelationshipController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              final newContact = EmergencyContact(
                name: _contactNameController.text.trim(),
                phoneNumber: _contactPhoneController.text.trim(),
                relationship: _contactRelationshipController.text.trim(),
              );

              setState(() {
                if (index != null) {
                  emergencyContacts[index] = newContact;
                } else {
                  emergencyContacts.add(newContact);
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(index != null ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle:true,
        title: Text("Profile", style: TextStyle(color: Color(0xFF212121), fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: Color(0xFF212121)),
        actions: [
          if (!isEditing)
            IconButton(icon: Icon(Icons.edit), onPressed: () => setState(() => isEditing = true))
          else
            TextButton(child: Text('Cancel', style: TextStyle(color: Colors.red,fontWeight:FontWeight.w800)), onPressed: () => setState(() => isEditing = false)),

          const SizedBox(width: 15),
        ],
      ),
      floatingActionButton: isEditing ?  ElevatedButton(
        onPressed: () {
          _saveChanges();
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor: Color(0xFF1F2937),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text('Save Changes', style: TextStyle(fontSize: 16)),
      ) : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(Duration(milliseconds: 200));
          setState(() {});
          _loadContacts();
        },
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection("Users").doc(widget.uid).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: Color(0xFF000000)));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text("No Data Available", style: TextStyle(fontSize: 16, color: Color(0xFF757575))));
            }

            UserModel user = UserModel.fromJson(snapshot.data!.data() as Map<String, dynamic>);
            if (_nameController.text.isEmpty) {
              _nameController.text = user.name;
              _phoneController.text = user.phoneNumber;
              _addressController.text = user.address;
              _msgController.text = user.msg;
            }

            return Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(20),
                children: [
                  // Profile Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: Offset(0, 10))],
                    ),
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Color(0xff000000).withOpacity(0.08),
                          backgroundImage: user.profileImageUrl != "" ? NetworkImage(user.profileImageUrl) : null,
                          child: user.profileImageUrl == "" ? Icon(Icons.person, size: 60, color: Color(0xFF000000)) : null,
                        ),
                        SizedBox(height: 20),
                        isEditing ? TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                          validator: (v) => v?.isEmpty == true ? 'Please enter your name' : null,
                        ) : Text(user.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF212121))),
                        SizedBox(height: 6),
                        Text(user.email, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Color(0xff000000).withOpacity(0.08), borderRadius: BorderRadius.circular(30)),
                          child: Text(user.admin ? "Admin" : "Member", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF000000))),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Personal Information Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: Offset(0, 10))],
                    ),
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Color(0xff000000).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.person_outline, color: Color(0xFF000000), size: 20),
                            ),
                            SizedBox(width: 12),
                            Text("Personal Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF212121))),
                          ],
                        ),
                        SizedBox(height: 24),

                        // Phone
                        isEditing ? TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                        ) : _buildInfoRow(Icons.phone_outlined, "Phone Number", user.phoneNumber),

                        Divider(height: 32),

                        // Address
                        isEditing ? TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on), border: OutlineInputBorder()),
                          maxLines: 2,
                        ) : _buildInfoRow(Icons.location_on_outlined, "Address", user.address),

                        Divider(height: 32),
                        _buildInfoRow(Icons.fingerprint, "User ID", user.id),
                      ],
                    ),
                  ),

                  if (!user.admin) ...[
                    SizedBox(height: 24),
                    // Emergency Contacts Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: Offset(0, 10))],
                      ),
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Color(0xff000000).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                    child: Icon(Icons.contact_emergency_outlined, color: Color(0xFF000000), size: 20),
                                  ),
                                  SizedBox(width: 12),
                                  Text("Emergency Contacts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF212121))),
                                ],
                              ),
                              if (isEditing)
                                TextButton.icon(
                                  onPressed: () => _showContactDialog(),
                                  icon: Icon(Icons.add, size: 16),
                                  label: Text("Add"),
                                  style: TextButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                    foregroundColor: Colors.grey[700],
                                    textStyle: TextStyle(fontSize: 13),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 24),

                          if (emergencyContacts.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                children: [
                                  Icon(Icons.contacts_outlined, size: 40, color: Colors.grey.withOpacity(0.4)),
                                  SizedBox(height: 12),
                                  Text("No emergency contacts", style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                  if (isEditing) Text("Add contacts for emergency situations", style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                                ],
                              ),
                            )
                          else
                            ...emergencyContacts.asMap().entries.map((entry) {
                              int i = entry.key;
                              EmergencyContact contact = entry.value;
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  border: i == emergencyContacts.length - 1 ? null : Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48, height: 48,
                                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
                                      child: Center(child: Text(contact.name.isNotEmpty ? contact.name[0].toUpperCase() : 'C', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]))),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(contact.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF212121))),
                                          Text(contact.relationship, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                          Row(
                                            children: [
                                              Icon(Icons.phone_outlined, size: 14, color: Colors.grey[500]),
                                              SizedBox(width: 6),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () async {
                                                    final uri = Uri(scheme: 'tel', path: contact.phoneNumber);
                                                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                                                    else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch phone dialer')));
                                                  },
                                                  child: Text(contact.phoneNumber, style: TextStyle(fontSize: 14, color: Colors.grey[700], decoration: TextDecoration.underline)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isEditing)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(onPressed: () => _showContactDialog(i), icon: Icon(Icons.edit_outlined), iconSize: 18, color: Colors.grey[600]),
                                          IconButton(
                                              onPressed: () => showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text('Delete Contact'),
                                                  content: Text('Delete ${contact.name}?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                                                    TextButton(
                                                      onPressed: () {
                                                        setState(() => emergencyContacts.removeAt(i));
                                                        Navigator.pop(context);
                                                      },
                                                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              icon: Icon(Icons.delete_outline), iconSize: 18, color: Colors.grey[600]
                                          ),
                                        ],
                                      )
                                    else
                                      IconButton(
                                        onPressed: () async {
                                          final phoneNumber = contact.phoneNumber.trim();
                                          print(phoneNumber);
                                          final uri = Uri(scheme: 'tel', path: phoneNumber);

                                          try {
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(
                                                uri,
                                                mode: LaunchMode.externalApplication,
                                              );

                                            } else {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Could not launch phone dialer')),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error: ${e.toString()}')),
                                              );
                                            }
                                          }
                                        },
                                        icon: Icon(Icons.call_outlined),
                                        iconSize: 16,
                                        color: Colors.grey[700],
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
                  ],
                  if (!user.admin) ...[
                    SizedBox(height: 24),
                    // Emergency msg
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: Offset(0, 10))],
                      ),
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [


                                  Text("Emergency Message", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF212121))),

                            ],
                          ),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(vertical: 22),
                              child: Column(
                                children: [
                                  isEditing ?
                                  TextFormField(
                                    controller: _msgController,
                                    decoration: InputDecoration(labelText: 'Emergency Message', prefixIcon: Icon(Icons.sms_outlined), border: OutlineInputBorder()),
                                  ) : _buildInfoRow(Icons.sms_outlined, "Emergency Message", user.msg),
                                  ],
                              ),
                            )

                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(color: Color(0xff000000).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Color(0xFF000000), size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF212121))),
            ],
          ),
        ),
      ],
    );
  }
}