import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../services/opc_bridge_service.dart';
import 'home_screen.dart';
import 'main_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Company> _clients = [];
  bool _isLoading = true;
  int _passwordResetCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TicketProvider>().fetchTickets(silent: true);
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bridge = OpcBridgeService();
      final data = await bridge.fetchClients();
      final resets = await bridge.fetchPasswordResetRequests();
      if (mounted) {
        context.read<CompanyProvider>().setCompanies(data);
        setState(() {
          _clients = data;
          _passwordResetCount = resets.where((r) => r['status'] == 'pending').length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clients: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticketProvider = context.watch<TicketProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Armix OEM Portal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          if (_passwordResetCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.lock_reset, color: Colors.amberAccent),
                  tooltip: 'Password Reset Requests',
                  onPressed: _showPasswordResetRequests,
                ),
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$_passwordResetCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
          IconButton(icon: const Icon(Icons.key), tooltip: 'View Client Passwords', onPressed: _showPasswordsDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.brightness == Brightness.dark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFF1565C0), const Color(0xFFE3F2FD)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildOverview(theme, ticketProvider),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text('Managed Clients',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(16.0),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.5,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final client = _clients[index];
                              return _ClientCard(client: client);
                            },
                            childCount: _clients.length,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Recent Pending Tickets',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final tickets = ticketProvider.tickets.where((t) => !t.isResolved).toList();
                            if (tickets.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No pending tickets', style: TextStyle(color: Colors.white70)),
                              );
                            }
                            final ticket = tickets[index];
                            return _buildTicketItem(context, ticket);
                          },
                          childCount: ticketProvider.tickets.where((t) => !t.isResolved).isEmpty
                              ? 1
                              : ticketProvider.tickets.where((t) => !t.isResolved).length,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 50)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildOverview(ThemeData theme, TicketProvider ticketProvider) {
    return Row(
      children: [
        _StatItem(label: 'Total Clients', value: _clients.length.toString(), icon: Icons.business),
        const SizedBox(width: 12),
        _StatItem(
            label: 'Open Tickets',
            value: ticketProvider.openTicketCount.toString(),
            icon: Icons.confirmation_number,
            color: Colors.orange),
        const SizedBox(width: 12),
        _StatItem(
            label: 'In Progress',
            value: ticketProvider.inProgressTicketCount.toString(),
            icon: Icons.timer,
            color: Colors.greenAccent),
        const SizedBox(width: 12),
        // ADD CLIENT CARD
        _AddClientStatItem(onTap: _showAddClientDialog),
        const SizedBox(width: 12),
        _RemoveClientStatItem(onTap: _showRemoveClientDialog),
      ],
    );
  }

  void _showRemoveClientDialog() {
    if (_clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No clients to remove.')),
      );
      return;
    }
    Company? selectedClient = _clients.first;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.person_remove, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove Client'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select the client to permanently remove. This will delete all their data.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Company>(
                value: selectedClient,
                decoration: InputDecoration(
                  labelText: 'Select Client',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _clients.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.name),
                )).toList(),
                onChanged: (val) => setDialogState(() => selectedClient = val),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('This action cannot be undone.', style: TextStyle(color: Colors.red, fontSize: 13))),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Remove'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedClient == null) return;
                Navigator.pop(ctx);
                await _confirmAndRemoveClient(selectedClient!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndRemoveClient(Company client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: Text('Are you sure you want to permanently remove "${client.name}" and all their data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final bridge = OpcBridgeService();
      await bridge.removeClient(client.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${client.name}" removed successfully.'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing client: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddClientDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddClientDialog(
        onSuccess: (result) {
          _loadData();
          _showGeneratedPasswordDialog(result);
        },
      ),
    );
  }

  void _showGeneratedPasswordDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Client Created!'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share these credentials with your client:', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _CredentialRow(label: 'Username', value: result['username']?.toString() ?? ''),
            const SizedBox(height: 8),
            _CredentialRow(label: 'Password', value: result['plainPassword']?.toString() ?? '', isPassword: true),
            const SizedBox(height: 8),
            _CredentialRow(label: 'Client ID', value: result['clientId']?.toString() ?? ''),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  void _showPasswordsDialog() async {
    try {
      final bridge = OpcBridgeService();
      final passwords = await bridge.fetchClientPasswords();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.key, color: Colors.amber),
            SizedBox(width: 8),
            Text('Client Passwords'),
          ]),
          content: SizedBox(
            width: 500,
            child: passwords.isEmpty
                ? const Text('No client accounts found.')
                : SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Company')),
                        DataColumn(label: Text('Username')),
                        DataColumn(label: Text('Password')),
                      ],
                      rows: passwords.map((p) => DataRow(cells: [
                        DataCell(Text(p['company_name']?.toString() ?? '-')),
                        DataCell(Text(p['username']?.toString() ?? '-')),
                        DataCell(Text(p['plain_password']?.toString() ?? '(not set)',
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                      ])).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showPasswordResetRequests() async {
    try {
      final bridge = OpcBridgeService();
      final requests = await bridge.fetchPasswordResetRequests();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.lock_reset, color: Colors.amber),
            SizedBox(width: 8),
            Text('Password Reset Requests'),
          ]),
          content: SizedBox(
            width: 500,
            child: requests.isEmpty
                ? const Text('No pending reset requests.')
                : SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Username')),
                        DataColumn(label: Text('Company')),
                        DataColumn(label: Text('Their Password')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: requests.map((r) => DataRow(cells: [
                        DataCell(Text(r['username']?.toString() ?? '-')),
                        DataCell(Text(r['company_name']?.toString() ?? '-')),
                        DataCell(Text(r['plain_password']?.toString() ?? '(not set)',
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                        DataCell(Text(r['status']?.toString() ?? '-')),
                      ])).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildTicketItem(BuildContext context, SupportTicket ticket) {
    final color = ticket.isOpen ? Colors.red : Colors.orange;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(Icons.warning, color: color)),
        title: Text(ticket.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Client: ${ticket.clientName} • Status: ${ticket.statusLabel}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 3)));
        },
      ),
    );
  }
}

// ── Add Client Dialog ─────────────────────────────────────────────────────────

class _AddClientDialog extends StatefulWidget {
  final void Function(Map<String, dynamic> result) onSuccess;
  const _AddClientDialog({required this.onSuccess});

  @override
  State<_AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<_AddClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _customMachineController = TextEditingController();
  final List<String> _allMachines = ['BM6 eco', 'BM3'];
  final List<String> _selectedMachines = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _customMachineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.person_add, color: Colors.blue),
        SizedBox(width: 8),
        Text('Add New Client'),
      ]),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Company Name *',
                    prefixIcon: const Icon(Icons.business),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Company name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text('Machine Models', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Select machines for this client:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _allMachines.map((machine) {
                    final selected = _selectedMachines.contains(machine);
                    return FilterChip(
                      label: Text(machine),
                      selected: selected,
                      selectedColor: Colors.blue.withValues(alpha: 0.2),
                      checkmarkColor: Colors.blue,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedMachines.add(machine);
                          } else {
                            _selectedMachines.remove(machine);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customMachineController,
                        decoration: InputDecoration(
                          labelText: 'Add Custom Machine Model',
                          prefixIcon: const Icon(Icons.settings),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.blue),
                        onPressed: () {
                          final name = _customMachineController.text.trim();
                          if (name.isNotEmpty) {
                            setState(() {
                              if (!_allMachines.contains(name)) {
                                _allMachines.add(name);
                              }
                              if (!_selectedMachines.contains(name)) {
                                _selectedMachines.add(name);
                              }
                              _customMachineController.clear();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check),
          label: Text(_isSubmitting ? 'Creating...' : 'Create Client'),
          onPressed: _isSubmitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final bridge = OpcBridgeService();
      final result = await bridge.addClient(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _selectedMachines,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _CredentialRow extends StatefulWidget {
  final String label;
  final String value;
  final bool isPassword;
  const _CredentialRow({required this.label, required this.value, this.isPassword = false});

  @override
  State<_CredentialRow> createState() => _CredentialRowState();
}

class _CredentialRowState extends State<_CredentialRow> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final displayValue = widget.isPassword && _hidden ? '••••••••' : widget.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text('${widget.label}: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(displayValue,
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ),
          if (widget.isPassword)
            IconButton(
              icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off, size: 18),
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color ?? Colors.white70, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _AddClientStatItem extends StatelessWidget {
  final VoidCallback onTap;
  const _AddClientStatItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.teal.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.white, size: 24),
              SizedBox(height: 8),
              Text('Add Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Create new account', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveClientStatItem extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveClientStatItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.deepOrange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_remove_alt_1, color: Colors.white, size: 24),
              SizedBox(height: 8),
              Text('Remove Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Delete client account', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Company client;
  const _ClientCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final isOnline = client.isOnline;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  client.name,
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOnline ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.grey,
                    fontSize: 10, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            client.location, 
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.precision_manufacturing, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text(
                'Machines: ${client.totalMachines}', 
                style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
              ),
            ],
          ),
          if (client.latestDowntimeReason != null && client.latestDowntimeReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Downtime: ${client.latestDowntimeReason}',
                    style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              // Monitor Portal Button
              Expanded(
                child: InkWell(
                  onTap: () {
                    context.read<CompanyProvider>().selectCompanyById(client.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dashboard_outlined, size: 14, color: isDark ? Colors.blue.shade300 : Colors.blue.shade800),
                        const SizedBox(width: 4),
                        Text(
                          'Portal',
                          style: TextStyle(
                            fontSize: 12, 
                            color: isDark ? Colors.blue.shade300 : Colors.blue.shade800, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Machine Control Button
              Expanded(
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => _MachineControlDialog(client: client),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.power_settings_new, size: 14, color: isDark ? Colors.purple.shade300 : Colors.deepPurple),
                        const SizedBox(width: 4),
                        Text(
                          'Control',
                          style: TextStyle(
                            fontSize: 12, 
                            color: isDark ? Colors.purple.shade300 : Colors.deepPurple, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}// ── Machine Control Dialog ─────────────────────────────────────────────────────

const _kMachineList = [
  {'id': 'BH-001',   'name': 'Board Hopper (Main Vibrator)'},
  {'id': 'BFC-002',  'name': 'Board Feeder Conveyor'},
  {'id': 'BMH-003',  'name': 'Base Mix Hopper Gate'},
  {'id': 'BMFB-004', 'name': 'Base Mix Filler Box'},
  {'id': 'M-005',    'name': 'Mould'},
  {'id': 'TH-006',   'name': 'Tamper Head'},
  {'id': 'FMH-007',  'name': 'Face Mix Hopper Gate'},
  {'id': 'FMFB-008', 'name': 'Face Mix Filler Box'},
  {'id': 'FMTL-009', 'name': 'Face Mix Table Lifter'},
  {'id': 'VBC-010',  'name': 'V-Belt Conveyor'},
  {'id': 'SV-011',   'name': 'Stacker Vertical'},
  {'id': 'SH-012',   'name': 'Stacker Horizontal'},
  {'id': 'RCC-013',  'name': 'Rack Chain Conveyor'},
];

class _MachineControlDialog extends StatefulWidget {
  final Company client;
  const _MachineControlDialog({required this.client});

  @override
  State<_MachineControlDialog> createState() => _MachineControlDialogState();
}

class _MachineControlDialogState extends State<_MachineControlDialog> {
  /// { machineId: enabled }  — true = running allowed, false = admin disabled
  final Map<String, bool> _overrides = {};
  final Map<String, Machine> _liveMachines = {};
  bool _isLoading = true;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _loadOverrides();
  }

  Future<void> _loadOverrides() async {
    setState(() => _isLoading = true);
    try {
      final bridge = OpcBridgeService();
      final data   = await bridge.getMachineOverrides(widget.client.id);
      
      // Fetch live machines to get current statuses
      final dashboardData = await bridge.fetchDashboardData(widget.client.id);
      final List<Machine> machines = List<Machine>.from(dashboardData['machines'] ?? []);

      if (mounted) {
        setState(() {
          _overrides.clear();
          _overrides.addAll(data);
          // Machines not in map are implicitly enabled
          for (final m in _kMachineList) {
            _overrides.putIfAbsent(m['id']!, () => true);
          }
          _liveMachines.clear();
          for (final lm in machines) {
            _liveMachines[lm.id] = lm;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          for (final m in _kMachineList) {
            _overrides.putIfAbsent(m['id']!, () => true);
          }
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load overrides: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _toggle(String machineId, bool newValue) async {
    setState(() => _saving.add(machineId));
    try {
      final bridge = OpcBridgeService();
      await bridge.setMachineOverride(widget.client.id, machineId, newValue);
      if (mounted) {
        setState(() {
          _overrides[machineId] = newValue;
          _saving.remove(machineId);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_machineName(machineId)} is now ${newValue ? 'ALLOWED' : 'BLOCKED'} for ${widget.client.name}'),
          backgroundColor: newValue ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving.remove(machineId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _machineName(String id) =>
      _kMachineList.firstWhere((m) => m['id'] == id, orElse: () => {'name': id})['name']!;

  @override
  Widget build(BuildContext context) {
    final disabledCount = _overrides.values.where((v) => !v).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.power_settings_new, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Expanded(child: Text('Machine Control — ${widget.client.name}',
                style: const TextStyle(fontSize: 16))),
          ]),
          if (disabledCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$disabledCount machine${disabledCount != 1 ? 's' : ''} currently admin-disabled',
                  style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 520,
        height: 540,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header legend
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('Toggle ALLOW/BLOCK to control machine access for this client.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                        _buildLegendPill('ALLOW', Colors.green),
                        const SizedBox(width: 6),
                        _buildLegendPill('BLOCK', Colors.red),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  // Machine list
                  Expanded(
                    child: ListView.builder(
                      itemCount: _kMachineList.length,
                      itemBuilder: (context, index) {
                        final m       = _kMachineList[index];
                        final id      = m['id']!;
                        final enabled = _overrides[id] ?? true;
                        final isSaving = _saving.contains(id);
                        final liveMachine = _liveMachines[id];
                        final isRunning = liveMachine?.isRunning ?? false;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: enabled
                                ? (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.05))
                                : (isDark ? Colors.red.withValues(alpha: 0.10)   : Colors.red.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: enabled
                                    ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2))
                                    : Colors.red.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Status icon representing operational live status
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isRunning
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.15),
                                  ),
                                  child: Icon(
                                    isRunning ? Icons.play_arrow_rounded : Icons.stop_rounded,
                                    color: isRunning ? Colors.green : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Machine name + id + live status
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m['name']!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: enabled ? null : Colors.grey.shade500,
                                          )),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(id,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: enabled
                                                    ? Colors.blueGrey
                                                    : Colors.red.withValues(alpha: 0.6),
                                              )),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 6, height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isRunning ? Colors.green : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isRunning ? 'Running' : 'Stopped',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isRunning ? Colors.green : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // ── Custom ALLOW/BLOCK Toggle ──────────────────────────
                                isSaving
                                    ? const SizedBox(
                                        width: 32, height: 32,
                                        child: CircularProgressIndicator(strokeWidth: 2.5))
                                    : GestureDetector(
                                        onTap: () => _toggle(id, !enabled),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          width: 90,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            color: enabled ? Colors.green : Colors.red,
                                            boxShadow: [
                                              BoxShadow(
                                                color: (enabled ? Colors.green : Colors.red)
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  enabled ? Icons.lock_open_rounded : Icons.lock_rounded,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  enabled ? 'ALLOW' : 'BLOCK',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          onPressed: _loadOverrides,
        ),
      ],
    );
  }

  Widget _buildLegendPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
