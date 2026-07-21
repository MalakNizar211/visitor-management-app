import 'qr_result_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/visit_model.dart';
import 'services/visit_service.dart';
import 'new_visitor_page.dart';
import 'loginpage.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final VisitService visitService = VisitService();
  final ScrollController _scrollController = ScrollController();

  final List<Visit> _visits = [];
  static const int _pageSize = 20;
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final newVisits = await visitService.getMyVisits(
      page: _page,
      pageSize: _pageSize,
    );

    setState(() {
      _visits.addAll(newVisits);
      _page++;
      _isLoading = false;
      _hasMore = newVisits.length == _pageSize;
    });
  }

  Future<void> _refreshVisits() async {
    setState(() {
      _visits.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text("HR Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshVisits,
        child: _visits.isEmpty && !_isLoading
            ? const Center(
          child: Text(
            'No visitors registered yet.',
            style: TextStyle(fontSize: 18),
          ),
        )
            : ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _visits.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _visits.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final visit = _visits[index];
            String _statusLabel(String status) {
              switch (status) {
                case 'pending':
                  return 'Pending';
                case 'checked_in':
                  return 'Checked In';
                case 'checked_out':
                  return 'Checked Out';
                case 'invalid':
                  return 'Invalid';
                default:
                  return status;
              }
            }

            Color _statusColor(String status) {
              switch (status) {
                case 'pending':
                  return Colors.orange[100]!;
                case 'checked_in':
                  return Colors.green[100]!;
                case 'checked_out':
                  return Colors.grey[300]!;
                case 'invalid':
                  return Colors.red[100]!;
                default:
                  return Colors.grey[300]!;
              }
            }

            Color _statusTextColor(String status) {
              switch (status) {
                case 'pending':
                  return Colors.orange[800]!;
                case 'checked_in':
                  return Colors.green[800]!;
                case 'checked_out':
                  return Colors.black54;
                case 'invalid':
                  return Colors.red[800]!;
                default:
                  return Colors.black54;
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visit.visitorName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('National ID: ${visit.nationalId}'),
                          Text('Phone: ${visit.phone}'),
                          Text('Visiting: ${visit.hostName}'),
                          Text('Purpose: ${visit.purpose}'),
                          Text('Visit time: ${visit.visitTime}'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(visit.status),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(visit.status),
                              style: TextStyle(
                                color: _statusTextColor(visit.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code,
                          color: Colors.lightBlue, size: 32),
                      tooltip: 'View QR Code',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QrResultPage(
                              visitId: visit.id!,
                              visitorName: visit.visitorName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.lightBlue,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewVisitorPage()),
          );
          _refreshVisits();
        },
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('New Visitor', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}