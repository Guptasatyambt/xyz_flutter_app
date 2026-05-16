import 'package:flutter/material.dart';
import '../models/driver_models.dart';
import '../services/driver_service.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  List<DriverVehicle> _vehicles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _vehicles = await DriverService.listVehicles();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSheet({DriverVehicle? vehicle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VehicleFormSheet(
        vehicle: vehicle,
        onSaved: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  Future<void> _delete(DriverVehicle vehicle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vehicle?'),
        content: Text(
          'Remove ${vehicle.make} ${vehicle.model} (${vehicle.plateNumber})?'
          ' This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await DriverService.deleteVehicle(vehicle.id);
      if (mounted) {
        setState(() => _vehicles.removeWhere((v) => v.id == vehicle.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _toggleActive(DriverVehicle vehicle) async {
    try {
      final updated = await DriverService.updateVehicle(
        vehicle.id,
        {'isActive': !vehicle.isActive},
      );
      if (mounted) {
        setState(() {
          final idx = _vehicles.indexWhere((v) => v.id == vehicle.id);
          if (idx != -1) _vehicles[idx] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Vehicles',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: BackButton(color: const Color(0xFF1A1A2E)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _vehicles.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _vehicles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _VehicleTile(
                          vehicle: _vehicles[i],
                          onEdit: () => _openSheet(vehicle: _vehicles[i]),
                          onDelete: () => _delete(_vehicles[i]),
                          onToggleActive: () => _toggleActive(_vehicles[i]),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_car_outlined, size: 64, color: Color(0xFFBDBDBD)),
          const SizedBox(height: 12),
          const Text(
            'No vehicles yet',
            style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a vehicle to start accepting rides',
            style: TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openSheet(),
            icon: const Icon(Icons.add),
            label: const Text('Add Vehicle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C6BC0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vehicle tile ───────────────────────────────────────────────────────────────

class _VehicleTile extends StatelessWidget {
  final DriverVehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _VehicleTile({
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: vehicle.isActive
                  ? const Color(0xFFE8EAF6)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              vehicle.typeIcon,
              color: vehicle.isActive
                  ? const Color(0xFF5C6BC0)
                  : const Color(0xFFBDBDBD),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle.make} ${vehicle.model} (${vehicle.year})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${vehicle.typeLabel} • ${vehicle.plateNumber}'
                  '${vehicle.color != null ? ' • ${vehicle.color}' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: vehicle.isActive
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    vehicle.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      color: vehicle.isActive
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<_VehicleAction>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF9E9E9E)),
            onSelected: (action) {
              switch (action) {
                case _VehicleAction.edit:
                  onEdit();
                case _VehicleAction.toggleActive:
                  onToggleActive();
                case _VehicleAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _VehicleAction.edit,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: Color(0xFF424242)),
                    SizedBox(width: 10),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _VehicleAction.toggleActive,
                child: Row(
                  children: [
                    Icon(
                      vehicle.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
                      color: const Color(0xFF424242),
                    ),
                    const SizedBox(width: 10),
                    Text(vehicle.isActive ? 'Set Inactive' : 'Set Active'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: _VehicleAction.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _VehicleAction { edit, toggleActive, delete }

// ── Add / Edit vehicle bottom sheet ───────────────────────────────────────────

class _VehicleFormSheet extends StatefulWidget {
  final DriverVehicle? vehicle; // null = add, non-null = edit
  final VoidCallback onSaved;

  const _VehicleFormSheet({this.vehicle, required this.onSaved});

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late final TextEditingController _makeCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _colorCtrl;
  bool _saving = false;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _type     = v?.type ?? kVehicleTypes.first;
    _makeCtrl  = TextEditingController(text: v?.make ?? '');
    _modelCtrl = TextEditingController(text: v?.model ?? '');
    _yearCtrl  = TextEditingController(text: v != null ? '${v.year}' : '');
    _plateCtrl = TextEditingController(text: v?.plateNumber ?? '');
    _colorCtrl = TextEditingController(text: v?.color ?? '');
  }

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await DriverService.updateVehicle(widget.vehicle!.id, {
          'type': _type,
          'make': _makeCtrl.text.trim(),
          'model': _modelCtrl.text.trim(),
          'year': int.parse(_yearCtrl.text.trim()),
          'plateNumber': _plateCtrl.text.trim().toUpperCase(),
          if (_colorCtrl.text.trim().isNotEmpty)
            'color': _colorCtrl.text.trim()
          else
            'color': null,
        });
      } else {
        await DriverService.createVehicle(
          type: _type,
          make: _makeCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
          year: int.parse(_yearCtrl.text.trim()),
          plateNumber: _plateCtrl.text.trim().toUpperCase(),
          color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
        );
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Edit Vehicle' : 'Add Vehicle',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Vehicle Type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kVehicleTypes.map((t) {
                final selected = _type == t;
                return ChoiceChip(
                  label: Text(_typeLabel(t)),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t),
                  selectedColor: const Color(0xFF5C6BC0),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF424242),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _field(_makeCtrl, 'Make', 'e.g. Honda')),
                const SizedBox(width: 12),
                Expanded(child: _field(_modelCtrl, 'Model', 'e.g. Activa')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _yearCtrl,
                    'Year',
                    'e.g. 2022',
                    inputType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final y = int.tryParse(v);
                      if (y == null || y < 1980 || y > 2030) return 'Invalid year';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_plateCtrl, 'Plate Number', 'e.g. MH12AB1234'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(_colorCtrl, 'Color (optional)', 'e.g. Red', required: false),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Update Vehicle' : 'Save Vehicle',
                        style: const TextStyle(fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String t) => switch (t) {
        'BIKE'      => 'Bike',
        'AUTO'      => 'Auto',
        'CAR_MINI'  => 'Mini',
        'CAR_SEDAN' => 'Sedan',
        'CAR_SUV'   => 'SUV',
        _           => t,
      };

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType inputType = TextInputType.text,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      validator: validator ??
          (v) {
            if (required && (v == null || v.trim().isEmpty)) return 'Required';
            return null;
          },
    );
  }
}
