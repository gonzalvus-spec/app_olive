import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Agregado para seguridad
import 'dart:convert';
import '../mongo_service.dart';

class VentanaChatIA extends StatefulWidget {
  const VentanaChatIA({super.key});

  @override
  State<VentanaChatIA> createState() => _VentanaChatIAState();
}

class _VentanaChatIAState extends State<VentanaChatIA> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _mensajes = [];
  bool _cargando = false;

  // EXTRAEMOS LA LLAVE DESDE EL ARCHIVO .ENV PARA QUE NO SE FILTRE EN GITHUB
  final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    // ================= MENSAJE DE BIENVENIDA =================
    _mensajes.add({
      "rol": "ia",
      "texto": "¡Hola! Soy Olivo-IA 🫒. Estoy listo para ayudarte con el control de tus pedidos, deudas y entregas de Cosecha Verde. ¿Qué deseas consultar hoy?"
    });
  }

  Future<void> _enviarPregunta() async {
    if (_controller.text.trim().isEmpty) return;
    if (_apiKey.isEmpty) {
      setState(() => _mensajes.add({"rol": "ia", "texto": "⚠️ Error: No se encontró la API Key en el archivo .env"}));
      return;
    }

    String preguntaUsuario = _controller.text;
    setState(() {
      _mensajes.add({"rol": "usuario", "texto": preguntaUsuario});
      _cargando = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      String datosContextoIA = "";
      final ventas = await MongoService.getVentas();
      
      if (ventas.isEmpty) {
        datosContextoIA = "No hay pedidos en la base de datos.";
      } else {
        for (var v in ventas) {
          String situacionPago = (v['pagado'] == true) ? "PAGADO" : "DEBE DINERO";
          String situacionEntrega = (v['entregado'] == true) ? "YA ENTREGADO" : "PENDIENTE DE ENTREGA";

          // Lógica para manejar el nuevo formato de productos (carrito)
          String detalleItems = "";
          if (v['productos'] != null && (v['productos'] as List).isNotEmpty) {
            List productos = v['productos'];
            detalleItems = productos.map((p) => "${p['cantidad']} ${p['producto']}").join(", ");
          } else {
            detalleItems = v['detalle'] ?? 'Sin detalle';
          }

          datosContextoIA += """
---
CLIENTE: ${v['cliente']}
DETALLE EXACTO: $detalleItems
MONTO: S/.${v['monto']}
ESTADO PAGO: $situacionPago
ESTADO ENTREGA: $situacionEntrega
FECHA: ${v['fecha']}
""";
        }
      }

      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content": """Eres 'Olivo-IA' de la Cosecha Verde.
              REGLA DE ORO: Debes decir la cantidad exacta que aparece en 'DETALLE EXACTO'. 
              
              TAREAS:
              - Si preguntan por entregas, lista solo los 'PENDIENTE DE ENTREGA'.
              - Si preguntan por deudas, lista los que dicen 'DEBE DINERO'.
              - Responde de forma amable y breve.
              
              DATOS REALES DE LA BASE DE DATOS:
              $datosContextoIA"""
            },
            {"role": "user", "content": preguntaUsuario}
          ],
          "temperature": 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _mensajes.add({
            "rol": "ia", 
            "texto": data['choices'][0]['message']['content'].toString().trim()
          });
        });
      }
    } catch (e) {
      setState(() => _mensajes.add({"rol": "ia", "texto": "⚠️ Error al conectar con Olivos del Campo."}));
    } finally {
      setState(() => _cargando = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      resizeToAvoidBottomInset: true, 
      appBar: AppBar(
        elevation: 2,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text("🫒", style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Olivo-IA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text("Cosecha Verde - En línea", style: TextStyle(fontSize: 12, color: Colors.teal[100])),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              itemCount: _mensajes.length,
              itemBuilder: (context, i) => _buildBurbuja(_mensajes[i]),
            ),
          ),
          if (_cargando) 
             Padding(
               padding: const EdgeInsets.only(bottom: 8.0),
               child: Center(child: CircularProgressIndicator(color: Colors.teal[800], strokeWidth: 2)),
             ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildBurbuja(Map<String, String> m) {
    bool esUsuario = m['rol'] == 'usuario';
    return Align(
      alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: esUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: esUsuario ? Colors.teal[800] : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(esUsuario ? 18 : 0),
                bottomRight: Radius.circular(esUsuario ? 0 : 18),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
              ],
            ),
            child: Text(
              m['texto']!,
              style: TextStyle(
                color: esUsuario ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4, right: 4),
            child: Text(
              esUsuario ? "Tú" : "Olivo-IA",
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 10, 
        right: 10, 
        top: 10, 
        bottom: MediaQuery.of(context).padding.bottom + 10, 
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: "Escribe una consulta...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _enviarPregunta(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _enviarPregunta,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.teal[800],
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}