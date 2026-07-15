import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/responsive.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  @override
  void initState() {
    super.initState();
    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TicketProvider>().fetchTickets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final ticketProvider = context.watch<TicketProvider>();
    final isAdmin = authProvider.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Master Support Desk' : 'Support Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ticketProvider.fetchTickets(),
          ),
        ],
      ),
      body: ticketProvider.isLoading && ticketProvider.tickets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, isAdmin, ticketProvider),
      floatingActionButton: !isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showRaiseTicketDialog(context),
              icon: const Icon(Icons.add_comment),
              label: const Text('Raise Ticket'),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, bool isAdmin, TicketProvider provider) {
    if (provider.tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No tickets found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.tickets.length,
      itemBuilder: (context, index) {
        final ticket = provider.tickets[index];
        return _TicketCard(ticket: ticket, isAdmin: isAdmin);
      },
    );
  }

  void _showRaiseTicketDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raise Support Ticket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Issue Title',
                hintText: 'e.g. Machine 03 Vibrator Overload',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the problem in detail...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                final success = await context.read<TicketProvider>().createTicket(
                  titleController.text,
                  descController.text,
                );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket raised successfully!')),
                  );
                }
              }
            },
            child: const Text('Submit Ticket'),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatefulWidget {
  final SupportTicket ticket;
  final bool isAdmin;

  const _TicketCard({required this.ticket, required this.isAdmin});

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  Timer? _timer;
  late Duration _currentWorkDuration;

  @override
  void initState() {
    super.initState();
    _currentWorkDuration = widget.ticket.workDuration ?? Duration.zero;
    if (widget.ticket.isAcknowledged) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentWorkDuration = widget.ticket.workDuration ?? Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TicketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ticket.isAcknowledged && !oldWidget.ticket.isAcknowledged) {
      _startTimer();
    } else if (widget.ticket.isResolved) {
      _timer?.cancel();
      _currentWorkDuration = widget.ticket.workDuration ?? Duration.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final color = _getStatusColor(ticket.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    ticket.statusLabel.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatDate(ticket.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ticket.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              ticket.description,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.business, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    ticket.clientName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (ticket.isAcknowledged || ticket.isResolved) ...[
                    const Icon(Icons.timer_outlined, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_currentWorkDuration),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (ticket.isOpen)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.read<TicketProvider>().acknowledgeTicket(ticket.id),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Acknowledge'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                    ),
                  if (ticket.isAcknowledged)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.read<TicketProvider>().resolveTicket(ticket.id),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Mark Resolved'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                  if (ticket.isResolved)
                    const Expanded(
                      child: Center(
                        child: Text(
                          '✅ Ticket Resolved Successfully',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ] else if (ticket.isAcknowledged || ticket.isResolved) ...[
              const SizedBox(height: 12),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ticket.isResolved ? 'Resolved in:' : 'Work in progress:',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _formatDuration(_currentWorkDuration),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return Colors.blue;
      case TicketStatus.acknowledged: return Colors.orange;
      case TicketStatus.resolved: return Colors.green;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
