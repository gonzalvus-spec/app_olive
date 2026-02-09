import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../mongo_service.dart';

class VentanaNuevoCliente extends StatefulWidget {
  const VentanaNuevoCliente({super.key});

  @override
  State<VentanaNuevoCliente> createState() => _VentanaNuevoClienteState();
}

class _VentanaNuevoClienteState extends State<VentanaNuevoCliente> {
  final TextEditingController _controller = TextEditingController();
  String? _distritoSeleccionado;
  bool _cargando = false;
  Key _refreshKey = UniqueKey();

  // Variables para controlar la paginación
  int _limiteClientes = 10;

  final Color _verdeOscuro = const Color(0xFF004D40);
  final Color _accentGreen = const Color(0xFF00BFA5);

  final List<String> _distritosLima = [
    "Ancón", "Ate", "Barranco", "Breña", "Carabayllo", "Chaclacayo", "Chorrillos",
    "Cieneguilla", "Comas", "El Agustino", "Independencia", "Jesús María", "La Molina",
    "La Victoria", "Lima (Cercado)", "Lince", "Los Olivos", "Lurigancho-Chosica",
    "Lurín", "Magdalena del Mar", "Miraflores", "Pachacámac", "Pucusana", "Pueblo Libre",
    "Puente Piedra", "Punta Hermosa", "Punta Negra", "Rímac", "San Bartolo",
    "San Borja", "San Isidro", "San Juan de Lurigancho", "San Juan de Miraflores",
    "San Luis", "San Martín de Porres", "San Miguel", "Santa Anita", "Santa María del Mar",
    "Santa Rosa", "Santiago de Surco", "Surquillo", "Villa El Salvador", "Villa María del Triunfo"
  ];

  void _guardar() async {
    String nombre = _controller.text.trim();
    
    if (nombre.isEmpty || _distritoSeleccionado == null) {
      _mostrarSnackBar("⚠️ Completa el nombre y selecciona un distrito");
      return;
    }

    setState(() => _cargando = true);

    try {
      var existe = await MongoService.clientesCollection!.findOne({"nombre": nombre});
      if (existe != null) {
        setState(() => _cargando = false);
        _mostrarError("El cliente '$nombre' ya existe.");
        return;
      }

      await MongoService.insertCliente({
        "nombre": nombre,
        "distrito": _distritoSeleccionado,
        "fecha_registro": DateTime.now(),
      });

      _controller.clear();
      setState(() {
        _distritoSeleccionado = null;
        _cargando = false;
        _refreshKey = UniqueKey(); 
      });
      _mostrarDialogoExito();
    } catch (e) {
      setState(() => _cargando = false);
      _mostrarSnackBar("Error al guardar: $e");
    }
  }

  void _abrirModalEdicion(Map<String, dynamic> cliente) {
    TextEditingController editCtrl = TextEditingController(text: cliente['nombre']);
    String? editDist = cliente['distrito'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 25, right: 25, top: 25),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Editar Información", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: editCtrl,
                decoration: InputDecoration(labelText: "Nombre", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _distritosLima.contains(editDist) ? editDist : null,
                decoration: InputDecoration(labelText: "Distrito", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                items: _distritosLima.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setModalState(() => editDist = val),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _verdeOscuro, minimumSize: const Size(double.infinity, 50)),
                onPressed: () async {
                  await MongoService.clientesCollection!.update(
                    mongo.where.id(cliente['_id']),
                    mongo.modify.set('nombre', editCtrl.text.trim()).set('distrito', editDist)
                  );
                  Navigator.pop(context);
                  setState(() => _refreshKey = UniqueKey());
                  _mostrarSnackBar("✅ Cliente actualizado");
                },
                child: const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarEliminar(Map<String, dynamic> cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar cliente?"),
        content: Text("Esta acción borrará a ${cliente['nombre']} de forma permanente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () async {
              await MongoService.clientesCollection!.remove(mongo.where.id(cliente['_id']));
              Navigator.pop(context);
              setState(() => _refreshKey = UniqueKey());
              _mostrarSnackBar("🗑️ Cliente eliminado");
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  
  void _mostrarError(String msg) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Aviso"), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
  }

  void _mostrarDialogoExito() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Registro Exitoso"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(title: const Text("Gestión de Clientes"), backgroundColor: _verdeOscuro, foregroundColor: Colors.white, centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildFormHeader(),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Row(children: [
                Icon(Icons.list_alt, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text("CLIENTES REGISTRADOS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              ]),
            ),
            const SizedBox(height: 10),
            _buildListaClientes(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(color: _verdeOscuro, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40))),
      child: Column(children: [
        const Icon(Icons.person_add_alt_1_rounded, size: 50, color: Colors.white),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: "Nombre Completo",
                    prefixIcon: Icon(Icons.badge_outlined, color: _verdeOscuro),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(15)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _distritoSeleccionado,
                      isExpanded: true,
                      hint: const Text("Selecciona Distrito"),
                      items: _distritosLima.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) => setState(() => _distritoSeleccionado = val),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _cargando 
                  ? const CircularProgressIndicator() 
                  : ElevatedButton.icon(
                      onPressed: _guardar,
                      icon: const Icon(Icons.save),
                      label: const Text("GUARDAR CLIENTE", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildListaClientes() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: _refreshKey,
      future: MongoService.getClientesData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }
        
        final todosLosClientes = snapshot.data ?? [];
        if (todosLosClientes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("No hay clientes registrados"),
          );
        }

        // Lógica de filtrado por cantidad
        final clientesAMostrar = todosLosClientes.take(_limiteClientes).toList();

        return Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: clientesAMostrar.length,
              itemBuilder: (context, index) {
                final cliente = clientesAMostrar[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _verdeOscuro.withOpacity(0.1), 
                      child: Text(
                        cliente['nombre'] != null && cliente['nombre'].isNotEmpty ? cliente['nombre'][0].toUpperCase() : "?", 
                        style: TextStyle(color: _verdeOscuro, fontWeight: FontWeight.bold)
                      )
                    ),
                    title: Text(cliente['nombre'] ?? "Sin nombre", style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(cliente['distrito'] ?? 'Sin distrito'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _abrirModalEdicion(cliente)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmarEliminar(cliente)),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Botón VER MÁS si hay más clientes disponibles
            if (todosLosClientes.length > _limiteClientes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _limiteClientes += 10;
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text("VER MÁS CLIENTES (${todosLosClientes.length - _limiteClientes} ocultos)"),
                  style: TextButton.styleFrom(
                    foregroundColor: _verdeOscuro,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}