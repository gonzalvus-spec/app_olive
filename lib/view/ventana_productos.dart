import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../mongo_service.dart';

class VentanaNuevoProducto extends StatefulWidget {
  const VentanaNuevoProducto({super.key});

  @override
  State<VentanaNuevoProducto> createState() => _VentanaNuevoProductoState();
}

class _VentanaNuevoProductoState extends State<VentanaNuevoProducto> {
  final TextEditingController _controller = TextEditingController();
  bool _cargando = false;
  Key _refreshKey = UniqueKey(); // Para actualizar la lista

  final Color _verdeOscuro = const Color(0xFF004D40);
  final Color _accentGreen = const Color(0xFF00BFA5);

  // --- GUARDAR PRODUCTO ---
  void _guardar() async {
    String nombre = _controller.text.trim();
    if (nombre.isEmpty) {
      _mostrarSnackBar("⚠️ Ingresa el nombre del producto");
      return;
    }

    setState(() => _cargando = true);

    try {
      await MongoService.insertProducto({
        "nombre": nombre,
        "fecha_creacion": DateTime.now(),
        "disponible": true,
      });

      _controller.clear();
      setState(() {
        _cargando = false;
        _refreshKey = UniqueKey(); // Refresca la lista inferior
      });
      _mostrarSnackBar("✅ Producto registrado con éxito");
    } catch (e) {
      setState(() => _cargando = false);
      _mostrarSnackBar("Error: $e");
    }
  }

  // --- EDITAR PRODUCTO ---
  void _abrirModalEdicion(Map<String, dynamic> producto) {
    TextEditingController editCtrl = TextEditingController(text: producto['nombre']);
    bool disponible = producto['disponible'] ?? true;

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
              const Text("Editar Producto", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: editCtrl,
                decoration: InputDecoration(labelText: "Nombre", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              SwitchListTile(
                title: const Text("Disponible para venta"),
                value: disponible,
                activeColor: _accentGreen,
                onChanged: (val) => setModalState(() => disponible = val),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _verdeOscuro, minimumSize: const Size(double.infinity, 50)),
                onPressed: () async {
                  await MongoService.productosCollection!.update(
                    mongo.where.id(producto['_id']),
                    mongo.modify.set('nombre', editCtrl.text.trim()).set('disponible', disponible)
                  );
                  Navigator.pop(context);
                  setState(() => _refreshKey = UniqueKey());
                  _mostrarSnackBar("✅ Producto actualizado");
                },
                child: const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- ELIMINAR PRODUCTO ---
  void _confirmarEliminar(Map<String, dynamic> producto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar producto?"),
        content: Text("Se borrará '${producto['nombre']}' del inventario."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () async {
              await MongoService.productosCollection!.remove(mongo.where.id(producto['_id']));
              Navigator.pop(context);
              setState(() => _refreshKey = UniqueKey());
              _mostrarSnackBar("🗑️ Producto eliminado");
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(title: const Text("Inventario de Productos"), backgroundColor: _verdeOscuro, foregroundColor: Colors.white, centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderForm(),
            const SizedBox(height: 20),
            _buildSeccionLista(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderForm() {
    return Container(
      padding: const EdgeInsets.only(bottom: 30),
      decoration: BoxDecoration(color: _verdeOscuro, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(50))),
      child: Column(children: [
        const Icon(Icons.inventory_2_outlined, size: 50, color: Colors.white),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: "Nuevo Producto",
                    prefixIcon: Icon(Icons.add_shopping_cart, color: _verdeOscuro),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                _cargando 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("REGISTRAR PRODUCTO", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
              ]),
            ),
          ),
        )
      ]),
    );
  }

  Widget _buildSeccionLista() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 25),
          child: Text("PRODUCTOS EN CATÁLOGO", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          key: _refreshKey,
          future: MongoService.getProductosData(), // Asegúrate de crear este método en MongoService
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No hay productos registrados"));

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final prod = snapshot.data![index];
                bool disp = prod['disponible'] ?? true;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200)
                  ),
                  child: ListTile(
                    leading: Icon(Icons.circle, color: disp ? _accentGreen : Colors.red, size: 12),
                    title: Text(prod['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(disp ? "En stock" : "Agotado", style: TextStyle(color: disp ? Colors.teal : Colors.red)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _abrirModalEdicion(prod)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmarEliminar(prod)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}