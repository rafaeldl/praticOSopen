import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/services/customer_directory.dart';
import 'package:praticos/utils/customer_utils.dart';

/// A vehicle found by plate and the customer it belongs to.
class PlateHit {
  const PlateHit(this.device, this.customer);

  final Device device;
  final Customer customer;
}

/// Finds customers by the plate of their vehicle.
///
/// Loads the company's vehicles once, matches the typed text against their
/// plates, and resolves the owner of each match (customer of its most recent
/// order). [onChanged] fires when an owner arrives, so the screen can rebuild.
class PlateLookup {
  PlateLookup(this._directory, {required this.onChanged});

  final CustomerDirectory _directory;
  final void Function() onChanged;

  List<Device> _devices = const [];
  final Map<String, String?> _ownerByDevice = {};
  final Set<String> _resolving = {};
  bool _disposed = false;

  Future<void> load() async {
    try {
      _devices = await _directory.loadDevices();
      if (!_disposed) onChanged();
    } catch (_) {
      // Plate search is a convenience: name and phone search keep working.
    }
  }

  /// Starts resolving the owners of the vehicles matching [query].
  void search(String query) {
    for (final device in _devices.where((d) => deviceMatchesPlate(d, query))) {
      final id = device.id;
      if (id == null || _ownerByDevice.containsKey(id) || !_resolving.add(id)) {
        continue;
      }
      _directory.ownerIdOf(device).then((owner) {
        _ownerByDevice[id] = owner;
      }).catchError((_) {
        _ownerByDevice[id] = null;
      }).whenComplete(() {
        if (!_disposed) onChanged();
      });
    }
  }

  /// Vehicles matching [query] whose owner is among [customers] (max 5).
  List<PlateHit> hits(String query, List<Customer> customers) {
    final byId = {for (final c in customers) c.id: c};
    final hits = <PlateHit>[];
    for (final device in _devices) {
      if (!deviceMatchesPlate(device, query)) continue;
      final customer = byId[_ownerByDevice[device.id]];
      if (customer != null) hits.add(PlateHit(device, customer));
    }
    return hits.take(5).toList();
  }

  void dispose() => _disposed = true;
}
