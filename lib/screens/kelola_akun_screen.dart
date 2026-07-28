import 'package:flutter/material.dart';
import '../services/api_service.dart';

class KelolaAkunScreen extends StatefulWidget {
  const KelolaAkunScreen({super.key});

  @override
  State<KelolaAkunScreen> createState() => _KelolaAkunScreenState();
}

class _KelolaAkunScreenState extends State<KelolaAkunScreen> {
  static const Color tombolCyan = Color(0xFF29C5E8);

  late Future<List<Map<String, dynamic>>> _futureUsers;

  @override
  void initState() {
    super.initState();
    _futureUsers = ApiService.getUsers();
  }

  void _muatUlang() {
    setState(() => _futureUsers = ApiService.getUsers());
  }

  Future<void> _dialogTambah() async {
    final namaController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'petugas';
    final formKey = GlobalKey<FormState>();

    final berhasil = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Tambah Akun'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: namaController,
                    decoration: const InputDecoration(labelText: 'Nama'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Petugas'),
                          value: 'petugas',
                          groupValue: role,
                          onChanged: (v) => setStateDialog(() => role = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Admin'),
                          value: 'admin',
                          groupValue: role,
                          onChanged: (v) => setStateDialog(() => role = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await ApiService.tambahUser(
                    name: namaController.text.trim(),
                    email: emailController.text.trim(),
                    password: passwordController.text,
                    role: role,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (berhasil == true) _muatUlang();
  }

  Future<void> _hapus(int id, String nama) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Akun?'),
        content: Text('Akun "$nama" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;

    try {
      await ApiService.hapusUser(id);
      _muatUlang();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: const Text('Kelola Akun'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureUsers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final users = snapshot.data ?? [];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final u = users[index];
              final isAdmin = u['role'] == 'admin';
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAdmin ? tombolCyan : Colors.grey.shade300,
                    child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person,
                        color: isAdmin ? Colors.black87 : Colors.black54),
                  ),
                  title: Text(u['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${u['email']} • ${u['role']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _hapus(u['id'], u['name']),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: tombolCyan,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Akun', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _dialogTambah,
      ),
    );
  }
}
