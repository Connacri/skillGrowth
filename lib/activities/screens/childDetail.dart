import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../modèles.dart';

class ChildDetailScreen extends StatefulWidget {
  final Child child;

  const ChildDetailScreen({Key? key, required this.child}) : super(key: key);

  @override
  _ChildDetailScreenState createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  late Future<List<Course>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _coursesFuture = _loadChildCourses();
  }

  Future<List<Course>> _loadChildCourses() async {
    if (widget.child.enrolledCourses.isEmpty) return [];
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where(FieldPath.documentId, whereIn: widget.child.enrolledCourses)
          .get();

      return snapshot.docs
          .map((doc) => Course.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("Erreur chargement cours: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Course>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(widget.child.name, 
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'child-image-${widget.child.id}',
                        child: Image.network(
                          'https://picsum.photos/seed/${widget.child.id}/600/400',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildInfoChip(Icons.cake, '${widget.child.age} ans'),
                          const SizedBox(width: 10),
                          _buildInfoChip(
                            widget.child.gender == 'male' ? Icons.male : Icons.female,
                            widget.child.gender == 'male' ? 'Garçon' : 'Fille'
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Cours Inscrits',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('Aucun cours inscrit', 
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final course = snapshot.data![index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: _buildScheduleCard(course),
                      );
                    },
                    childCount: snapshot.data!.length,
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Course course) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course.name, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ...course.schedules
                .map(
                  (schedule) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_formatDayRange(schedule.days)}'),
                      Text(
                        '${_formatTime(schedule.startTime)} - ${_formatTime(schedule.endTime)}',
                      ),
                      Divider(),
                    ],
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  String _formatDayRange(List<String> days) {
    return days.join(', ');
  }

  String _formatTime(DateTime time) {
    return DateFormat.Hm().format(time);
  }
}
