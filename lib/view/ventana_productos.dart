import 'package:flutter/material.dart';
import '../mongo_service.dart';

class VentanaNuevoProducto extends StatefulWidget {
  const VentanaNuevoProducto({super.key});

  @override
  State<VentanaNuevoProducto> createState() => _VentanaNuevoProductoState();
}

class _VentanaNuevoProductoState extends State<VentanaNuevoProducto> {
  final TextEditingController _controller = TextEditingController();
  bool _cargando = false;

  void _guardar() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _cargando = true);
    // ENVIAMOS UN MAP como pide tu MongoService
    await MongoService.insertProducto({
      "nombre": _controller.text.trim(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nuevo Producto"),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Nombre del producto",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_basket),
              ),
            ),
            const SizedBox(height: 20),
            _cargando 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("GUARDAR PRODUCTO"),
                ),
          ],
        ),
      ),
    );
  }
}