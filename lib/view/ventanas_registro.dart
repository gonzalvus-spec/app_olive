import 'package:flutter/material.dart';
import '../mongo_service.dart';

class VentanaNuevoCliente extends StatefulWidget {
  const VentanaNuevoCliente({super.key});

  @override
  State<VentanaNuevoCliente> createState() => _VentanaNuevoClienteState();
}

class _VentanaNuevoClienteState extends State<VentanaNuevoCliente> {
  final TextEditingController _controller = TextEditingController();
  bool _cargando = false;

  void _guardar() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _cargando = true);
    // ENVIAMOS UN MAP como pide tu MongoService
    await MongoService.insertCliente({
      "nombre": _controller.text.trim(),
    });
    
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nuevo Cliente"),
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
                labelText: "Nombre del cliente",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
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
                  child: const Text("GUARDAR CLIENTE"),
                ),
          ],
        ),
      ),
    );
  }
}