import 'package:praticos/models/base_audit.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class Repository<T extends BaseAudit?> {
  final String collection;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Repository(this.collection);

  Future<T?> getSingle(String? id) async {
    var snap = await _db.collection(collection).doc(id).get();
    if (!snap.exists) return null;
    return _fromJsonID(id, snap.data()!);
  }

  Future<T> getSingleQuery(List<QueryArgs> queryArgs) async {
    List<T> resultList = await getQueryList(args: queryArgs);
    return resultList[0];
  }

  Stream<T> streamSingle(String? id) {
    return _db.collection(collection).doc(id).snapshots().map((snap) {
      return _fromJsonID(id, snap.data()!);
    });
  }

  Stream<List<T>> streamList() {
    var ref = _db.collection(collection);
    return ref.snapshots().map((list) => list.docs.map((doc) {
          return _fromJsonID(doc.id, doc.data());
        }).toList());
  }

  Future<List<T>> getQueryList(
      {List<OrderBy>? orderBy,
      List<QueryArgs>? args,
      int? limit,
      dynamic startAfter}) async {
    CollectionReference collref = _db.collection(collection);
    Query? ref;
    if (args != null) {
      for (QueryArgs arg in args) {
        String oper = arg.oper;
        if (ref == null) {
          ref = Function.apply(
              collref.where, [arg.key], {Symbol(oper): arg.value});
        } else {
          ref = Function.apply(
              ref.where, [arg.key], {Symbol(oper): arg.value});
        }
      }
    }
    if (orderBy != null) {
      for (var order in orderBy) {
        if (ref == null) {
          ref = collref.orderBy(order.field, descending: order.descending);
        } else {
          ref = ref.orderBy(order.field, descending: order.descending);
        }
      }
    }
    if (limit != null) {
      if (ref == null) {
        ref = collref.limit(limit);
      } else {
        ref = ref.limit(limit);
      }
    }
    if (startAfter != null && orderBy != null) {
      ref = ref!.startAfter([startAfter]);
    }
    QuerySnapshot query;
    if (ref != null) {
      query = await ref.get();
    } else {
      query = await collref.get();
    }

    return query.docs.map((doc) {
      return _fromJsonID(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Stream<List<T>> streamQueryList(
      {List<OrderBy>? orderBy, List<QueryArgs>? args}) {
    CollectionReference collref = _db.collection(collection);
    Query? ref;
    if (orderBy != null) {
      for (var order in orderBy) {
        if (ref == null) {
          ref = collref.orderBy(order.field, descending: order.descending);
        } else {
          ref = ref.orderBy(order.field, descending: order.descending);
        }
      }
    }
    if (args != null) {
      for (QueryArgs arg in args) {
        String oper = arg.oper;
        if (ref == null) {
          ref = Function.apply(
              collref.where, [arg.key], {Symbol(oper): arg.value});
        } else {
          ref = Function.apply(
              ref.where, [arg.key], {Symbol(oper): arg.value});
        }
      }
    }
    if (ref != null) {
      Stream<QuerySnapshot> querySnapshot = ref.snapshots();
      querySnapshot.handleError((onError) {
        print('onError');
        print(onError);
      });
      return querySnapshot.map((snap) => snap.docs.map((doc) {
            return _fromJsonID(doc.id, doc.data() as Map<String, dynamic>);
          }).toList());
    } else {
      return collref.snapshots().map((snap) => snap.docs.map((doc) {
            return _fromJsonID(doc.id, doc.data() as Map<String, dynamic>);
          }).toList());
    }
  }

  T _fromJsonID(String? id, Map<String, dynamic> data) {
    Map<String, dynamic> dataId = {};
    
    // Converte Timestamps para String ISO8601 antes de passar para o generated code
    data.forEach((key, value) {
      if (value is Timestamp) {
        dataId[key] = value.toDate().toIso8601String();
      } else {
        dataId[key] = value;
      }
    });
    
    dataId['id'] = id;
    return fromJson(dataId);
  }

  Future<List<T>> getListFromTo(String field, DateTime from, DateTime to,
      {List<QueryArgs> args = const []}) async {
    var ref = _db.collection(collection).orderBy(field);
    for (QueryArgs arg in args) {
      ref = ref.where(arg.key, isEqualTo: arg.value);
    }
    QuerySnapshot query = await ref.startAt([from]).endAt([to]).get();
    return query.docs.map((doc) {
      return _fromJsonID(doc.id, doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Stream<List<T>> streamListFromTo(String field, DateTime from, DateTime to,
      {List<QueryArgs> args = const []}) {
    var ref = _db.collection(collection).orderBy(field, descending: true);
    for (QueryArgs arg in args) {
      ref = ref.where(arg.key, isEqualTo: arg.value);
    }
    var query = ref.startAfter([to]).endAt([from]).snapshots();
    return query.map((snap) => snap.docs.map((doc) {
          return _fromJsonID(doc.id, doc.data());
        }).toList());
  }

  Future<dynamic> createItem(T item, {String? id}) {
    if (item?.id != null) {
      var json = toJson(item);
      json.remove("number");
      return _db
          .collection(collection)
          .doc(item?.id)
          .set(json, SetOptions(merge: true));
    } else {
      return _db
          .collection(collection)
          .add(toJson(item))
          .then((docRef) => item?.id = docRef.id);
    }
  }

  batchedSignup<U extends User, C extends Company, R extends UserRole>(
      U u, C c, R r) {
    WriteBatch batch = _db.batch();
    var userReference = _db.collection('users').doc(u.id);
    batch.set(userReference, u.toJson());

    var companyReference = _db.collection('companies').doc(c.id);
    batch.set(companyReference, c.toJson());

    var roleReference = _db.collection('roles').doc(c.id);
    batch.set(roleReference, r.toJson());

    batch.commit();
  }

  Future<void> updateItem(T item) {
    return _db
        .collection(collection)
        .doc(item?.id)
        .set(toJson(item), SetOptions(merge: true));
  }

  Future<void> removeItem(String? id) {
    return _db.collection(collection).doc(id).delete();
  }

  T fromJson(data);
  Map<String, dynamic> toJson(T item);
}

class QueryArgs {
  final String key;
  final String oper;
  final dynamic value;
  QueryArgs(this.key, this.value, {this.oper = 'isEqualTo'});
}

class OrderBy {
  final String field;
  final bool descending;
  OrderBy(this.field, {this.descending = false});
}
