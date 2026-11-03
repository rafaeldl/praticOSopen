/// Which orders a list query is limited to, as the Firestore order read
/// rule allows: the ones [uid] created and, when [assigned] (technician),
/// also the ones assigned to them (`assignedTo.id`). A null scope means
/// every order (admin, manager, supervisor).
class OrderScope {
  const OrderScope(this.uid, {this.assigned = false});

  final String uid;
  final bool assigned;

  @override
  bool operator ==(Object other) =>
      other is OrderScope && other.uid == uid && other.assigned == assigned;

  @override
  int get hashCode => Object.hash(uid, assigned);

  @override
  String toString() => 'OrderScope($uid, assigned: $assigned)';
}
