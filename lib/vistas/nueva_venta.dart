import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../mongo_service.dart';
import '../view/ventanas_registro.dart';
import '../view/ventana_productos.dart';

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
  List<String> _productos = [];
  List<String> _clientes = [];
  List<Map<String, dynamic>> _carrito = [];
  List<Map<String, dynamic>> _ventasHistorial = [];
  
  bool _estaGuardando = false;
  bool _mostrarHistorial = false; // Control de despliegue estilo Yape
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
      "t": "Oferta",
      "s": "Solicita tu pedido al instante hoy.",
      "c": const Color(0xFFE0F2F1),
      "img": "https://www.agraria.pe/imgs/a/lx/importadores-europeos-analizaron-potencial-de-la-aceituna-pe-17779.jpg",
      "tag": "AGRO"
    },
    {
      "t": "Finanzas",
      "s": "Usa la calculadora para tus cuentas.",
      "c": const Color(0xFFF3E5F5),
      "img": "https://almazaralaorganic.com/wp-content/uploads/2024/12/aceite-de-oliva.jpeg",
      "tag": "HERRAMIENTA"
    },
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
      final clientesDB = await MongoService.getClientes();
      final productosDB = await MongoService.getProductos();
      final ventasDB = await MongoService.getVentas();
      
      ventasDB.sort((a, b) {
        var fechaA = a['createdAt'] ?? DateTime(2000);
        var fechaB = b['createdAt'] ?? DateTime(2000);
        return fechaB.compareTo(fechaA);
      });

      if (mounted) {
        setState(() {
          _clientes = clientesDB;
          _productos = productosDB;
          _ventasHistorial = ventasDB;
        });
      }
    } catch (e) {
      print("Error cargando datos: $e");
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _etiquetaSeccion("CARRITO ACTUAL"),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 20, height: 20,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(color: _accentGreen, shape: BoxShape.circle),
                                    alignment: Alignment.center,
                                    child: Text(_carrito.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              _buildListaCarrito(),
                              const SizedBox(height: 15),
                              _buildTotalPanel(totalCarrito),
                            ],
                            const SizedBox(height: 30),
                            
                            // BLOQUE DESPLEGABLE ESTILO YAPE
                            GestureDetector(
                              onTap: () => setState(() => _mostrarHistorial = !_mostrarHistorial),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt_long, color: _verdeClaro),
                                    const SizedBox(width: 12),
                                    Text("Ver movimientos recientes", style: TextStyle(fontWeight: FontWeight.bold, color: _verdeOscuro)),
                                    const Spacer(),
                                    Icon(
                                      _mostrarHistorial ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            if (_mostrarHistorial) ...[
                              const SizedBox(height: 10),
                              _buildListaMovimientosHistoricos(),
                            ],
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

  // --- WIDGETS UI ---

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
                  right: 0, top: 0, bottom: 0,
                  child: Image.network(promos[i]['img'], fit: BoxFit.cover, width: MediaQuery.of(context).size.width * 0.45),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: FractionallySizedBox(
                    widthFactor: 0.55,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _verdeOscuro.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(promos[i]['tag'], style: TextStyle(color: _verdeOscuro, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        Text(promos[i]['t'], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _verdeOscuro)),
                        const SizedBox(height: 4),
                        Text(promos[i]['s'], style: const TextStyle(fontSize: 11, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
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
      children: List.generate(promos.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 7,
          width: _currentPage == index ? 18 : 7,
          decoration: BoxDecoration(color: _currentPage == index ? _accentGreen : Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
        );
      }),
    );
  }

  Widget _etiquetaSeccion(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 1.2)),
  );

  Widget _selectorCliente() {
    return InkWell(
      onTap: _abrirBuscadorClientes,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _clienteSeleccionado != null ? _accentGreen : Colors.transparent)),
        child: Row(children: [
          Icon(Icons.person, color: _clienteSeleccionado != null ? _accentGreen : Colors.grey),
          const SizedBox(width: 12),
          Text(_clienteSeleccionado ?? "Buscar Cliente...", style: TextStyle(fontWeight: _clienteSeleccionado != null ? FontWeight.bold : FontWeight.normal)),
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
        _buildDropdownProductos(),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildInput("Cant.", Icons.tag, _cantidadController)),
          const SizedBox(width: 10),
          Expanded(child: _buildInput("S/.", Icons.payments, _precioController, isNumber: true)),
          const SizedBox(width: 10),
          IconButton.filled(onPressed: _agregarAlCarrito, icon: const Icon(Icons.add_shopping_cart), style: IconButton.styleFrom(backgroundColor: _verdeClaro)),
        ]),
      ]),
    );
  }

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
          child: _estaGuardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("GUARDAR VENTA"),
        )),
      ]),
    );
  }

  void _agregarAlCarrito() {
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
  }

  Future<void> _finalizarPedido() async {
    if (_clienteSeleccionado == null || _carrito.isEmpty) return;
    setState(() => _estaGuardando = true);
    try {
      double montoCalculado = _carrito.fold(0.0, (sum, item) => sum + (item['subtotal'] as double));
      final DateTime ahora = DateTime.now();
      final String fechaFormatoFinal = DateFormat("dd MMM. yyyy - hh:mm a", 'es_ES').format(ahora).toLowerCase();

      final nuevaVenta = {
        "fecha": fechaFormatoFinal,
        "cliente": _clienteSeleccionado,
        "productos": _carrito,
        "monto": montoCalculado,
        "createdAt": ahora,
      };

      await MongoService.insertVenta(nuevaVenta);
      await _cargarDatosDeBaseDeDatos();
      setState(() { _carrito.clear(); _clienteSeleccionado = null; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Venta registrada")));
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _estaGuardando = false);
    }
  }

  Widget _buildInput(String hint, IconData icon, TextEditingController ctrl, {bool isNumber = false}) => TextField(
    controller: ctrl,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 16, color: _verdeClaro), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
  );

  Widget _buildDropdownProductos() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: _productoSeleccionado, hint: const Text("Producto"), isExpanded: true,
      items: _productos.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (nv) => setState(() => _productoSeleccionado = nv),
    )),
  );

  Widget _buildListaCarrito() => Column(
    children: _carrito.asMap().entries.map((entry) {
      int index = entry.key;
      var item = entry.value;
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(item['producto'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text("Cantidad: ${item['cantidad']}", style: const TextStyle(fontSize: 11)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("S/. ${item['subtotal']}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => setState(() => _carrito.removeAt(index)),
              )
            ],
          ),
        ),
      );
    }).toList()
  );

  Widget _buildListaMovimientosHistoricos() {
    if (_ventasHistorial.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(Icons.receipt_long, color: Colors.grey[300], size: 50),
              const SizedBox(height: 10),
              const Text("No hay ventas aún", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    bool hayMasDatos = _ventasHistorial.length > _limiteVentas;
    List<Map<String, dynamic>> ventasAMostrar = _ventasHistorial.take(_limiteVentas).toList();

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ventasAMostrar.length,
          itemBuilder: (context, i) {
            final v = ventasAMostrar[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: _verdeClaro.withOpacity(0.1), child: Icon(Icons.history, color: _verdeClaro, size: 18)),
              title: Text(v['cliente'] ?? "Cliente", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(v['fecha'] ?? "---", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              trailing: Text("S/. ${v['monto']?.toStringAsFixed(2) ?? '0.00'}", style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          },
        ),
        if (hayMasDatos)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextButton(
              onPressed: () => setState(() => _limiteVentas += 10),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              child: Text("VER MÁS VENTAS", style: TextStyle(color: _verdeClaro, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          )
      ],
    );
  }

  void _abrirBuscadorClientes() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _BuscadorModal(
      titulo: "Clientes", lista: _clientes, onSeleccion: (n) { setState(() => _clienteSeleccionado = n); Navigator.pop(context); },
    ));
  }
}

// --- MODALES ---

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
        _primerNumero = double.tryParse(_display) ?? 0; _operacion = valor; _operacionVisual = valor; _limpiarPantalla = true;
      } else if (valor == "=") {
        double seg = double.tryParse(_display) ?? 0;
        switch (_operacion) {
          case "+": _display = (_primerNumero + seg).toString(); break;
          case "-": _display = (_primerNumero - seg).toString(); break;
          case "x": _display = (_primerNumero * seg).toString(); break;
          case "/": _display = (seg != 0) ? (_primerNumero / seg).toString() : "Error"; break;
        }
        _operacion = ""; _operacionVisual = "";
      } else {
        if (_display == "0" || _limpiarPantalla) { _display = valor; _limpiarPantalla = false; } else { _display += valor; }
      }
      if (_display.endsWith(".0")) _display = _display.substring(0, _display.length - 2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(color: Color(0xFF121212), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Container(alignment: Alignment.bottomRight, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(_operacionVisual, style: const TextStyle(color: Colors.amber, fontSize: 35, fontWeight: FontWeight.bold)),
            const SizedBox(width: 15),
            Flexible(child: FittedBox(child: Text(_display, style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold)))),
          ])),
        const Divider(color: Colors.white10),
        const SizedBox(height: 10),
        Expanded(child: GridView.count(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, 
          children: ["7","8","9","/", "4","5","6","x", "1","2","3","-", "C","0","=","+"].map((btn) {
            bool isOp = ["/","x","-","+","="].contains(btn);
            return ElevatedButton(onPressed: () => _presionarBoton(btn),
              style: ElevatedButton.styleFrom(backgroundColor: btn == "C" ? Colors.redAccent : (isOp ? const Color(0xFF00BFA5) : Colors.grey[900]),
              foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 4),
              child: Text(btn, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)));
          }).toList())),
      ]),
    );
  }
}

class _BuscadorModal extends StatefulWidget {
  final String titulo; final List<String> lista; final Function(String) onSeleccion;
  const _BuscadorModal({required this.titulo, required this.lista, required this.onSeleccion});
  @override State<_BuscadorModal> createState() => _BuscadorModalState();
}

class _BuscadorModalState extends State<_BuscadorModal> {
  late List<String> filtrados;
  @override void initState() { super.initState(); filtrados = widget.lista; }
  @override Widget build(BuildContext context) {
    return DraggableScrollableSheet(initialChildSize: 0.8, builder: (_, controller) => Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        TextField(decoration: InputDecoration(hintText: "Buscar...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFFF0F2F5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
          onChanged: (v) => setState(() => filtrados = widget.lista.where((e) => e.toLowerCase().contains(v.toLowerCase())).toList())),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            controller: controller, 
            itemCount: filtrados.length, 
            itemBuilder: (ctx, i) => ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF00BFA5).withOpacity(0.1),
                child: const Icon(Icons.person_outline, color: Color(0xFF00BFA5), size: 20),
              ),
              title: Text(filtrados[i], style: const TextStyle(fontWeight: FontWeight.w500)), 
              onTap: () => widget.onSeleccion(filtrados[i])
            )
          )
        )
      ]),
    ));
  }
}