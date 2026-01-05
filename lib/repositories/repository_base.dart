import 'package:praticos/models/base_audit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class RepositoryBase<T extends BaseAudit> {
  final db = FirebaseFirestore.instance;

  delete(T entity);

  deleteAll(Iterable<T> entities);

  Page<T> findAll(PageRequest pageRequest);

  S save<S extends T>(T entity);

  Iterable<S> saveAll<S extends T>(Iterable<S> entities);
}

class PageRequest {
  // Info about the pagination
}

class Page<T extends BaseAudit> {
  late Iterable<T> content;

  List<T> getContentAsList() => content.toList();

  int getSize() => content.length;

  bool hasContent() => content.isNotEmpty ? true : false;
}
