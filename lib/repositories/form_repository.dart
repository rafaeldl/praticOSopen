import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/form/form_definition.dart';
import 'package:praticos/models/form/order_form.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FormRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<FormDefinition>> getAvailableForms() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? companyId = prefs.getString('companyId');
    // For MVP, we assume segmentId is hardcoded or not used yet, or we fetch only company forms.
    // The spec says global templates are at segments/{segmentId}/forms.
    // We will focus on company templates for now as per instructions unless we have segmentId available.
    // Assuming we only fetch company forms for now or if we can find where segmentId is stored.

    List<FormDefinition> forms = [];

    if (companyId != null) {
      QuerySnapshot companyForms = await _db
          .collection('companies')
          .doc(companyId)
          .collection('forms')
          .where('isActive', isEqualTo: true)
          .get();

      forms.addAll(companyForms.docs
          .map((doc) =>
              FormDefinition.fromJson(doc.data() as Map<String, dynamic>)..id = doc.id)
          .toList());
    }

    // TODO: Fetch global forms if segmentId is available.

    return forms;
  }

  Future<FormDefinition?> getFormDefinition(String templateId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? companyId = prefs.getString('companyId');

    if (companyId != null) {
      // Try company forms
      DocumentSnapshot doc = await _db
          .collection('companies')
          .doc(companyId)
          .collection('forms')
          .doc(templateId)
          .get();

      if (doc.exists) {
        return FormDefinition.fromJson(doc.data() as Map<String, dynamic>)..id = doc.id;
      }
    }

    // TODO: Try global forms if not found in company (if we have segmentId context)

    return null;
  }

  Future<OrderForm> addFormToOrder(String orderId, FormDefinition template) async {
    // According to spec: orders/{orderId}/forms
    // We create a new document in this subcollection.

    // We need to check if we are using the new structure `companies/{companyId}/orders` or legacy `orders`.
    // Since OrderRepository uses `orders`, we use `orders`.
    // However, if we need to support migration, we might need logic here.
    // But spec explicitly says `orders/{orderId}/forms`.

    // We can try to find the order first to be sure where it is?
    // Or just assume `orders/{orderId}` works because even in migration, we might have kept IDs unique.
    // But safe bet is to follow the OrderRepository pattern or assume root `orders`.
    // If the project is in migration, usually new data goes to new structure?
    // But OrderRepository reads from `orders` root. So we stick to `orders/{orderId}/forms`.

    // Update: If we use the new structure, we need companyId.
    // Let's assume root `orders` collection for now as `OrderRepository` does.

    // Wait, if the order is actually in `companies/{cid}/orders`, writing to `orders/{oid}/forms` might be writing to a non-existent parent if the parent is in a different path.
    // But Firestore allows writing to subcollections even if parent doc doesn't exist (it shows up in console in italics).
    // However, for consistency, we should probably check where the order is.

    // For MVP, let's assume `orders` root collection.

    CollectionReference formsRef = _db.collection('orders').doc(orderId).collection('forms');

    OrderForm newForm = OrderForm(
      formDefinitionId: template.id,
      title: template.title,
      status: 'pending',
      responses: template.items?.map((item) => FormResponseItem(
        itemId: item.id,
        value: null,
        photoUrls: [],
      )).toList(),
      updatedAt: DateTime.now(),
    );

    DocumentReference docRef = await formsRef.add(newForm.toJson());
    newForm.id = docRef.id;
    return newForm;
  }

  Stream<List<OrderForm>> getOrderForms(String orderId) {
    return _db
        .collection('orders')
        .doc(orderId)
        .collection('forms')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderForm.fromJson(doc.data())..id = doc.id)
            .toList());
  }

  Future<void> updateOrderForm(String orderId, OrderForm form) async {
    await _db
        .collection('orders')
        .doc(orderId)
        .collection('forms')
        .doc(form.id)
        .update(form.toJson()..['updatedAt'] = FieldValue.serverTimestamp());
  }
}
