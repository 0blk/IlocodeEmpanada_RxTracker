import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../services/medicine_provider.dart';
import '../widgets/hover_scale.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _sexController;
  late TextEditingController _bloodTypeController;

  @override
  void initState() {
    super.initState();
    final profile = context.read<MedicineProvider>().profile;
    _nameController = TextEditingController(text: profile?['full_name']);
    _ageController = TextEditingController(text: profile?['age']?.toString());
    _sexController = TextEditingController(text: profile?['sex']);
    _bloodTypeController = TextEditingController(text: profile?['blood_type']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _sexController.dispose();
    _bloodTypeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final success = await context.read<MedicineProvider>().updateProfile({
      'full_name': _nameController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()),
      'sex': _sexController.text.trim(),
      'blood_type': _bloodTypeController.text.trim(),
    });

    if (success && mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final profile = provider.profile;
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'User Email';

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.check), onPressed: _saveProfile),
                  ],
                ),
              ),
            const SizedBox(height: 40),
            // Avatar & Name
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                    child: const Icon(Icons.person, size: 80, color: Color(0xFF6366F1)),
                  ),
                  if (!_isEditing)
                    HoverScale(
                      onTap: () => setState(() => _isEditing = true),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFC6FF00),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 20, color: Colors.black),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _ageController, decoration: const InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: TextField(controller: _sexController, decoration: const InputDecoration(labelText: 'Sex'))),
                      ],
                    ),
                    TextField(controller: _bloodTypeController, decoration: const InputDecoration(labelText: 'Blood Type')),
                    const SizedBox(height: 24),
                    HoverScale(
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => setState(() => _isEditing = false), child: const Text('Cancel')),
                  ],
                ),
              )
            else ...[
              Text(
                profile?['full_name']?.toUpperCase() ?? email.split('@')[0].toUpperCase(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InfoChip(label: 'Age', value: profile?['age']?.toString() ?? '--'),
                  _InfoChip(label: 'Sex', value: profile?['sex'] ?? '--'),
                  _InfoChip(label: 'Blood', value: profile?['blood_type'] ?? '--'),
                ],
              ),
            ],
            const SizedBox(height: 40),

            // Info Section
            _ProfileItem(
              icon: Icons.notifications_none,
              title: 'Notifications',
              subtitle: 'Adjust medication alerts',
              onTap: () {},
            ),
            _ProfileItem(
              icon: Icons.security_outlined,
              title: 'Security',
              subtitle: 'Privacy and account safety',
              onTap: () {},
            ),
            _ProfileItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQs and contact us',
              onTap: () {},
            ),
            
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: HoverScale(
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
          ),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverScale(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF6366F1)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}
