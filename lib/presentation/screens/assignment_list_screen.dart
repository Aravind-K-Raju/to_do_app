import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/assignment_provider.dart';
import '../widgets/items/assignment_list_item.dart';
import 'assignment_add_edit_screen.dart';

class AssignmentListScreen extends StatefulWidget {
  const AssignmentListScreen({super.key});

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AssignmentProvider>(context, listen: false).loadAssignments();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: Consumer<AssignmentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final pending = provider.assignments
              .where((a) => !a.isCompleted)
              .toList();
          final completed = provider.assignments
              .where((a) => a.isCompleted)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(pending, provider),
              _buildList(completed, provider),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AssignmentAddEditScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(List assignments, AssignmentProvider provider) {
    if (assignments.isEmpty) {
      return const Center(child: Text('No assignments found.'));
    }
    return ListView.builder(
      itemCount: assignments.length,
      itemBuilder: (context, index) {
        final assignment = assignments[index];
        return Dismissible(
          key: Key(assignment.id.toString()),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            provider.delete(assignment.id!);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Assignment deleted')));
          },
          child: AssignmentListItem(
            assignment: assignment,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AssignmentAddEditScreen(assignment: assignment),
                ),
              );
            },
            onToggle: () {
              provider.toggleCompletion(assignment);
            },
          ),
        );
      },
    );
  }
}
