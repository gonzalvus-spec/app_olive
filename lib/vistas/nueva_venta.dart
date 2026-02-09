import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../mongo_service.dart';
import '../view/ventanas_registro.dart';
import '../view/ventana_productos.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VentanaHomeCompleta extends StatefulWidget {
  const VentanaHomeCompleta({super.key});

  @override
  State<VentanaHomeCompleta> createState() => _VentanaHomeCompletaState();
}

class _VentanaHomeCompletaState extends State<VentanaHomeCompleta> with AutomaticKeepAliveClientMixin {
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  
  String? _productoSeleccionado;
  String? _clienteSeleccionado;
  
  // Manejo de datos
  List<String> _productos = [];
  List<Map<String, dynamic>> _clientesFullData = []; // Para obtener el distrito
  List<String> _clientesNombres = [];               // Para el buscador
  List<Map<String, dynamic>> _carrito = [];
  List<Map<String, dynamic>> _ventasHistorial = [];
  
  bool _estaGuardando = false;
  bool _mostrarHistorial = false; 
  int _limiteVentas = 10;

  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  Timer? _timer;

  final Color _verdeOscuro = const Color(0xFF004D40);
  final Color _verdeClaro = const Color(0xFF00695C);
  final Color _accentGreen = const Color(0xFF00BFA5);

  @override
  bool get wantKeepAlive => true;

  final List<Map<String, dynamic>> promos = [
    {
      "t": "Aceitunas",
      "s": "Solicita tu pedido al instante hoy.",
      "c": const Color(0xFFF1F8E9),
      "img": "https://i.imgur.com/QRDPYS4.jpeg",
      "tag": "AGRO"
    },

    {
      "t": "Bienestar",
      "s": "Cuida tu salud con \noro líquido hoy.",
      "c": const Color(0xFFE8F5E9),
      "img": "https://i.imgur.com/eVa7bor.jpeg",
      "tag": "HERRAMIENTA"
    },
    
    {
      "t": "Al Por Mayor",
      "s": "Especial para tu \nnegocio hoy.",
      "c": const Color(0xFFFFFDE7),
      "img": "https://i.imgur.com/u7D8DTI.png",
      "tag": "VENTAS"
    },{
      "t": "Finanzas",
      "s": "Usa la calculadora \npara tus cuentas.",
      "c": const Color(0xFFF1F8E9),
      "img": "https://i.imgur.com/cIZbUDn.jpeg",
      "tag": "SALUD"
    },
    {
      "t": "Tradición",
      "s": "El sabor de siempre \nen tu mesa hoy.",
      "c": const Color(0xFFE8F5E9),
      "img": "https://i.imgur.com/McbSpKA.jpeg",
      "tag": "GOURMET"
    },
    {
      "t": "Logística",
      "s": "Recibe tu pedido en \ncasa pronto hoy.",
       "c": const Color(0xFFFFFDE7),
      "img": "https://i.imgur.com/NIX3NYn.png",
      "tag": "ENVÍOS"
    }
    
  ];

  @override
  void initState() {
    super.initState();
    _inicializarApp();
  }

  Future<void> _inicializarApp() async {
    await initializeDateFormatting('es_ES', null);
    await _cargarDatosDeBaseDeDatos(); 
    
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < promos.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 800), curve: Curves.easeIn);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosDeBaseDeDatos() async {
    try {
      final clientesDB = await MongoService.getClientesData(); 
      final productosDB = await MongoService.getProductos();
      final ventasDB = await MongoService.getVentas();
      
      if (mounted) {
        setState(() {
          _clientesFullData = clientesDB;
          _clientesNombres = clientesDB.map((c) => (c['nombre'] ?? "Sin nombre").toString()).toList();
          _productos = productosDB;
          _ventasHistorial = ventasDB;
        });
      }
    } catch (e) {
      print("Error cargando datos: $e");
    }
  }

  // --- LÓGICA DE GUARDADO CORREGIDA ---
  Future<void> _finalizarPedido() async {
    if (_clienteSeleccionado == null || _carrito.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Falta cliente o productos")));
      return;
    }
    
    setState(() => _estaGuardando = true);

    try {
      // 1. Buscamos el distrito del cliente en los datos cargados
      final clienteDoc = _clientesFullData.firstWhere(
        (c) => c['nombre'] == _clienteSeleccionado,
        orElse: () => {'distrito': 'DISTRITO'},
      );
      String distritoSeleccionado = clienteDoc['distrito'] ?? "DISTRITO";

      double totalMonto = _carrito.fold(0.0, (sum, item) => sum + (item['subtotal'] as double));
      final DateTime ahora = DateTime.now();
      final String fechaString = DateFormat("dd MMM. yyyy - hh:mm a", 'es_ES').format(ahora).toLowerCase();

      final nuevaVenta = {
        "fecha": fechaString,
        "cliente": _clienteSeleccionado,
        "distrito": distritoSeleccionado, // <--- CAMBIO CLAVE: Se guarda el distrito
        "productos": List.from(_carrito),
        "monto": totalMonto,
        "createdAt": ahora,
        "pagado": false,
        "entregado": false,
      };

      await MongoService.insertVenta(nuevaVenta);
      await _cargarDatosDeBaseDeDatos();
      
      setState(() { 
        _carrito.clear(); 
        _clienteSeleccionado = null; 
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Venta de $distritoSeleccionado guardada"), backgroundColor: Colors.green)
      );
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _estaGuardando = false);
    }
  }

  void _abrirCalculadora() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ModalCalculadora(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    double totalCarrito = _carrito.fold(0.0, (sum, item) => sum + (item['subtotal'] as double));

    return Scaffold(
      backgroundColor: _verdeOscuro,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargarDatosDeBaseDeDatos,
                color: _accentGreen,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 15),
                      _buildQuickActions(),
                      const SizedBox(height: 10),
                      _buildPromoBanner(),
                      const SizedBox(height: 8),
                      _buildIndicadores(),
                      const SizedBox(height: 15),
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _etiquetaSeccion("NUEVA VENTA"),
                            _selectorCliente(),
                            const SizedBox(height: 15),
                            _buildFormularioProducto(),
                            if (_carrito.isNotEmpty) ...[
                              const SizedBox(height: 25),
                              _etiquetaSeccion("CARRITO (${_carrito.length})"),
                              _buildListaCarrito(),
                              const SizedBox(height: 15),
                              _buildTotalPanel(totalCarrito),
                            ],
                            const SizedBox(height: 30),
                            _buildSeccionHistorial(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPONENTES DE UI ---

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.menu, color: Colors.white),
          const SizedBox(width: 15),
          const Text("Hola, Felix", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.notifications_none, color: Colors.white),
          const SizedBox(width: 15),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person, size: 20, color: Colors.white),
          )
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _actionBtn(Icons.people_outline, "Clientes", onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const VentanaNuevoCliente()));
            _cargarDatosDeBaseDeDatos();
          }),
          _actionBtn(Icons.add_shopping_cart, "Productos", onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const VentanaNuevoProducto()));
            _cargarDatosDeBaseDeDatos();
          }),
          _actionBtn(Icons.calculate_outlined, "Calculadora", onTap: _abrirCalculadora),
          _actionBtn(Icons.settings_rounded, "Ajustes", isAccent: true, onTap: () {}),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, {bool isAccent = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: isAccent ? _accentGreen : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
            ),
            child: Icon(icon, color: isAccent ? Colors.white : _verdeOscuro),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPromoBanner() {
    return SizedBox(
      height: 130,
      child: PageView.builder(
        controller: _pageController,
        itemCount: promos.length,
        onPageChanged: (index) => setState(() => _currentPage = index),
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: promos[i]['c'], borderRadius: BorderRadius.circular(25)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(
              children: [
                Positioned(
  right: 0,
  top: 0,
  bottom: 0,
  child: CachedNetworkImage(
    imageUrl: promos[i]['img'],
    width: MediaQuery.of(context).size.width * 0.45,
    fit: BoxFit.cover,
    // Mientras carga la imagen por primera vez
    placeholder: (context, url) => Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _verdeClaro.withOpacity(0.5),
        ),
      ),
    ),
    // Si falla la carga (por ejemplo, sin internet)
    errorWidget: (context, url, error) => Container(
      width: MediaQuery.of(context).size.width * 0.45,
      color: Colors.grey[200],
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
    ),
  ),
),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: FractionallySizedBox(
                    widthFactor: 0.55,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Busca esta parte dentro de Column en _buildPromoBanner
Text(
  promos[i]['t'], 
  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _verdeOscuro)
),
Text(
  promos[i]['s'],
  textAlign: TextAlign.left,
  style: const TextStyle(fontSize: 11),
)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicadores() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(promos.length, (index) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 7,
        width: _currentPage == index ? 18 : 7,
        decoration: BoxDecoration(color: _currentPage == index ? _accentGreen : Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
      )),
    );
  }

  Widget _etiquetaSeccion(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 1.2)),
  );

  Widget _selectorCliente() {
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context, 
        isScrollControlled: true, 
        backgroundColor: Colors.transparent, 
        builder: (context) => _BuscadorModal(
          titulo: "Clientes", 
          lista: _clientesNombres, 
          onSeleccion: (n) { setState(() => _clienteSeleccionado = n); Navigator.pop(context); }
        )
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _clienteSeleccionado != null ? _accentGreen : Colors.transparent)),
        child: Row(children: [
          Icon(Icons.person, color: _clienteSeleccionado != null ? _accentGreen : Colors.grey),
          const SizedBox(width: 12),
          Text(_clienteSeleccionado ?? "Buscar Cliente..."),
          const Spacer(),
          const Icon(Icons.search, size: 18, color: Colors.grey),
        ]),
      ),
    );
  }

  Widget _buildFormularioProducto() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _productoSeleccionado, hint: const Text("Seleccionar Producto"), isExpanded: true,
            items: _productos.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (nv) => setState(() => _productoSeleccionado = nv),
          )),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildInput("Cant.", Icons.tag, _cantidadController)),
          const SizedBox(width: 10),
          Expanded(child: _buildInput("S/.", Icons.payments, _precioController, isNumber: true)),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: () {
              if (_productoSeleccionado == null || _precioController.text.isEmpty) return;
              setState(() {
                _carrito.add({
                  "producto": _productoSeleccionado,
                  "cantidad": _cantidadController.text.isEmpty ? "1" : _cantidadController.text,
                  "subtotal": double.tryParse(_precioController.text) ?? 0.0,
                });
                _productoSeleccionado = null;
                _precioController.clear();
                _cantidadController.clear();
              });
            }, 
            icon: const Icon(Icons.add_box_rounded, size: 25),
            style: IconButton.styleFrom(backgroundColor: _verdeClaro)
          ),
        ]),
      ]),
    );
  }

  Widget _buildInput(String hint, IconData icon, TextEditingController ctrl, {bool isNumber = false}) => TextField(
    controller: ctrl,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 16, color: _verdeClaro), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
  );

  Widget _buildListaCarrito() => Column(
    children: _carrito.asMap().entries.map((entry) => Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(entry.value['producto'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text("Cantidad: ${entry.value['cantidad']}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("S/. ${entry.value['subtotal']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => setState(() => _carrito.removeAt(entry.key))),
          ],
        ),
      ),
    )).toList()
  );

  Widget _buildTotalPanel(double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [_verdeOscuro, _verdeClaro]), borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("TOTAL A PAGAR", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          Text("S/. ${total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 15),
        SizedBox(width: double.infinity, height: 45, child: ElevatedButton(
          onPressed: _estaGuardando ? null : _finalizarPedido,
          style: ElevatedButton.styleFrom(backgroundColor: _accentGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _estaGuardando ? const CircularProgressIndicator(color: Colors.white) : const Text("GUARDAR VENTA"),
        )),
      ]),
    );
  }

  Widget _buildSeccionHistorial() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _mostrarHistorial = !_mostrarHistorial),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Row(children: [
              Icon(Icons.receipt_long, color: _verdeClaro),
              const SizedBox(width: 12),
              const Text("Ver movimientos recientes", style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(_mostrarHistorial ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
            ]),
          ),
        ),
        if (_mostrarHistorial) ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ventasHistorial.take(_limiteVentas).length,
          itemBuilder: (context, i) {
            final v = _ventasHistorial[i];
            return ListTile(
              title: Text(v['cliente'] ?? "Cliente", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${v['fecha'] ?? ''} | ${v['distrito'] ?? ''}", style: const TextStyle(fontSize: 10)),
              trailing: Text("S/. ${v['monto']?.toStringAsFixed(2)}"),
            );
          },
        ),
      ],
    );
  }
}

// ================= MODALES AUXILIARES =================

class _ModalCalculadora extends StatefulWidget {
  const _ModalCalculadora();
  @override State<_ModalCalculadora> createState() => _ModalCalculadoraState();
}

class _ModalCalculadoraState extends State<_ModalCalculadora> {
  String _display = "0";
  String _operacionVisual = "";
  double _primerNumero = 0;
  String _operacion = "";
  bool _limpiarPantalla = false;

  void _presionarBoton(String valor) {
  setState(() {
    if (valor == "C") {
      _display = "0"; _operacionVisual = ""; _primerNumero = 0; _operacion = "";
    } else if (valor == "+" || valor == "-" || valor == "x" || valor == "/") {
      _primerNumero = double.tryParse(_display) ?? 0;
      _operacion = valor;
      _operacionVisual = valor;
      _limpiarPantalla = true;
    } else if (valor == "=") {
      double seg = double.tryParse(_display) ?? 0;
      
      switch (_operacion) {
        case "+": _display = (_primerNumero + seg).toString(); break;
        case "-": _display = (_primerNumero - seg).toString(); break;
        case "x": _display = (_primerNumero * seg).toString(); break;
        case "/": _display = (seg != 0) ? (_primerNumero / seg).toString() : "Error"; break;
      }
      _operacion = ""; _operacionVisual = "";
    } 
    // --- NUEVA LÓGICA PARA EL DECIMAL ---
    else if (valor == ".") {
      if (!_display.contains(".")) {
        _display += ".";
      }
    } 
    // ------------------------------------
    else {
      if (_display == "0" || _limpiarPantalla) {
        _display = valor;
        _limpiarPantalla = false;
      } else {
        _display += valor;
      }
    }
    
    // Quitamos el formateo automático de .0 para que no borre el punto mientras escribes
    // Solo lo aplicamos si no estamos editando un decimal
    if (!_display.contains(".") && _display.endsWith(".0")) {
       _display = _display.substring(0, _display.length - 2);
    }
  });
}

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF17171C), // Fondo oscuro mate
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: Column(
        children: [
          // Barra superior de arrastre
          const SizedBox(height: 12),
          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
          
          // Pantalla de resultados
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_operacionVisual, style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 32, fontWeight: FontWeight.w300)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _display,
                      style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w200),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Teclado
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                color: Color(0xFF212121), // Fondo teclado
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              child: GridView.count(
                padding: const EdgeInsets.all(10),
                crossAxisCount: 4,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                // Busca el final de la lista de botones en el GridView
children: [
  _btn("C", color: const Color(0xFF424242), textColor: Colors.redAccent),
  _btn("/", color: const Color(0xFF424242), isOp: true),
  _btn("x", color: const Color(0xFF424242), isOp: true),
  _btn("-", color: const Color(0xFF424242), isOp: true),
  _btn("7"), _btn("8"), _btn("9"),
  _btn("+", color: const Color(0xFF424242), isOp: true),
  _btn("4"), _btn("5"), _btn("6"),
  _btn("=", color: const Color(0xFF00BFA5), textColor: Colors.white), 
  _btn("1"), _btn("2"), _btn("3"),
  _btn("."), // <-- AGREGADO: Botón de punto decimal
  _btn("0", isZero: true),
].map((w) => w).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String txt, {Color? color, Color? textColor, bool isOp = false, bool isZero = false}) {
    return ElevatedButton(
      onPressed: () => _presionarBoton(txt),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFF2C2C2C),
        foregroundColor: textColor ?? (isOp ? const Color(0xFF00BFA5) : Colors.white),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: EdgeInsets.zero,
      ),
      child: Text(
        txt,
        style: TextStyle(
          fontSize: isOp ? 28 : 26,
          fontWeight: isOp ? FontWeight.bold : FontWeight.w400,
        ),
      ),
    );
  }
}
class _BuscadorModal extends StatefulWidget {
  final String titulo;
  final List<String> lista;
  final Function(String) onSeleccion;

  const _BuscadorModal({
    required this.titulo,
    required this.lista,
    required this.onSeleccion,
  });

  @override
  State<_BuscadorModal> createState() => _BuscadorModalState();
}

class _BuscadorModalState extends State<_BuscadorModal> {
  late List<String> filtrados;

  @override
  void initState() {
    super.initState();
    filtrados = widget.lista;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Margen superior para que no cubra toda la pantalla
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Barra pequeña decorativa arriba
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Buscar ${widget.titulo}...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00695C)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => filtrados = widget.lista
                  .where((e) => e.toLowerCase().contains(v.toLowerCase()))
                  .toList()),
            ),
          ),
          
          Expanded(
            child: ListView.separated(
              itemCount: filtrados.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, i) {
                // Obtenemos la inicial del nombre
                String inicial = filtrados[i].isNotEmpty ? filtrados[i][0].toUpperCase() : "?";
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF00BFA5).withOpacity(0.1),
                    child: Text(
                      inicial,
                      style: const TextStyle(
                        color: Color(0xFF004D40),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    filtrados[i],
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () => widget.onSeleccion(filtrados[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}