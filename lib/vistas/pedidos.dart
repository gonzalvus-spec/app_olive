import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Añadido para inicialización de fechas
import '../mongo_service.dart';

class VentanaPedidos extends StatefulWidget {
  const VentanaPedidos({super.key});

  @override
  State<VentanaPedidos> createState() => _VentanaPedidosState();
}

class _VentanaPedidosState extends State<VentanaPedidos> {
  // --- Variables para Paginación ---
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController(); 
  
  List<Map<String, dynamic>> _pedidosCargados = [];
  bool _estaCargando = false;
  bool _hayMasPedidos = true;
  final int _cantidadPorPagina = 15;

  DateTime? _fechaSeleccionada;

  @override
  void initState() {
    super.initState();
    // Inicializar datos locales para español/Perú
    initializeDateFormatting('es_PE', null);
    _cargarSiguientePagina(); // Carga inicial

    // Escuchar el scroll para paginación infinita
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_estaCargando &&
          _hayMasPedidos &&
          _fechaSeleccionada == null &&
          _searchController.text.isEmpty) {
        _cargarSiguientePagina();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Función auxiliar para limpiar el distrito ---
  String _limpiarDistrito(dynamic valor) {
    String raw = (valor ?? "").toString().trim();
    return (raw.isEmpty || raw.toLowerCase() == "null") ? "DISTRITO" : raw;
  }

  // ================= CARGA DE DATOS (PAGINACIÓN Y FILTROS) =================

  Future<void> _cargarSiguientePagina() async {
    if (_estaCargando) return;
    setState(() => _estaCargando = true);

    final nuevosPedidos = await MongoService.getVentasPaginadas(
      _pedidosCargados.length,
      _cantidadPorPagina,
    );

    setState(() {
      _estaCargando = false;
      if (nuevosPedidos.isEmpty) {
        _hayMasPedidos = false;
      } else {
        _pedidosCargados.addAll(nuevosPedidos);
      }
    });
  }

  Future<void> _buscarPorNombre(String nombre) async {
    if (nombre.isEmpty) {
      _refrescarLista();
      return;
    }
    setState(() {
      _estaCargando = true;
      _pedidosCargados.clear();
      _fechaSeleccionada = null; // Limpiar fecha al buscar por nombre
    });
    final resultados = await MongoService.getVentasPorNombre(nombre);
    setState(() {
      _pedidosCargados = resultados;
      _estaCargando = false;
      _hayMasPedidos = false;
    });
  }

  Future<void> _refrescarLista() async {
    setState(() {
      _pedidosCargados.clear();
      _hayMasPedidos = true;
      _fechaSeleccionada = null;
      _searchController.clear();
    });
    await _cargarSiguientePagina();
  }

  // ================= DIÁLOGO DE CONFIRMACIÓN =================
  Future<bool> _confirmarAccion({
    required String accion,
    required String cliente,
    required Color color,
    required IconData icono,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(icono, color: color),
                const SizedBox(width: 10),
                const Text("Confirmar", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("¿Estás seguro de realizar esta acción?"),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    accion.toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 15),
                Text("Cliente: $cliente", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("SÍ, CONFIRMAR", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ================= LÓGICA DE AGRUPACIÓN MODIFICADA PARA PERÚ =================
  Map<String, List<Map<String, dynamic>>> _agruparPorFecha(List<Map<String, dynamic>> ventas) {
    Map<String, List<Map<String, dynamic>>> grupos = {};
    for (var v in ventas) {
      String soloFecha;
      
      if (v['createdAt'] != null) {
        DateTime dt = v['createdAt'] is DateTime ? v['createdAt'] : DateTime.parse(v['createdAt'].toString());
        // Ajustamos a hora local (Perú) antes de formatear
        soloFecha = DateFormat("EEEE, d MMM. yyyy", 'es_PE').format(dt.toLocal());
      } else {
        String fechaCompleta = v['fecha'] ?? "Sin Fecha";
        soloFecha = fechaCompleta.contains(" - ") ? fechaCompleta.split(" - ")[0] : fechaCompleta;
      }

      if (!grupos.containsKey(soloFecha)) grupos[soloFecha] = [];
      grupos[soloFecha]!.add(v);
    }
    return grupos;
  }

  // ================= ACTUALIZAR / ELIMINAR =================
  void _update(Map<String, dynamic> venta, String campo) async {
    bool estadoActual = venta[campo] ?? false;
    String textoAccion = campo == 'pagado'
        ? (estadoActual ? "Desmarcar como DEUDA" : "Marcar como PAGADO")
        : (estadoActual ? "Marcar como PENDIENTE ENTREGA" : "Marcar como ENTREGADO");
    Color colorAccion = campo == 'pagado'
        ? (estadoActual ? Colors.orange : Colors.green)
        : (estadoActual ? Colors.blueGrey : Colors.blue);

    bool confirmar = await _confirmarAccion(
      accion: textoAccion,
      cliente: venta['cliente'] ?? "Cliente",
      color: colorAccion,
      icono: campo == 'pagado' ? Icons.payments : Icons.local_shipping,
    );

    if (confirmar) {
      bool nuevoEstado = !estadoActual;
      if (campo == 'pagado' && nuevoEstado == true) {
        await MongoService.updateEstado(venta['_id'], 'pagado', true);
        await MongoService.updateEstado(venta['_id'], 'entregado', true);
      } else {
        await MongoService.updateEstado(venta['_id'], campo, nuevoEstado);
      }
      if (mounted) {
        _refrescarLista();
      }
    }
  }

  void _delete(Map<String, dynamic> venta) async {
    bool confirmar = await _confirmarAccion(
      accion: "ELIMINAR ESTE PEDIDO DEFINITIVAMENTE",
      cliente: venta['cliente'] ?? "Cliente",
      color: Colors.redAccent,
      icono: Icons.delete_forever,
    );

    if (confirmar) {
      await MongoService.deleteVenta(venta['_id']);
      if (mounted) {
        _refrescarLista();
      }
    }
  }

  // ================= UI PRINCIPAL =================
  @override
  Widget build(BuildContext context) {
    final ventasAgrupadas = _agruparPorFecha(_pedidosCargados);
    final fechasKeys = ventasAgrupadas.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Control de Olivos", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: _seleccionarFecha),
          if (_fechaSeleccionada != null || _searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off, color: Colors.orangeAccent), 
              onPressed: _refrescarLista
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onSubmitted: _buscarPorNombre,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: "Buscar cliente por nombre...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refrescarLista,
        child: _estaCargando && _pedidosCargados.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : _pedidosCargados.isEmpty
                ? _estadoVacio("No hay registros.")
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: fechasKeys.length + (_hayMasPedidos ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == fechasKeys.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }

                      final fechaHeader = fechasKeys[index];
                      final ventasDia = ventasAgrupadas[fechaHeader]!;
                      double total = ventasDia.fold(0, (s, v) => s + (v['monto'] ?? 0));
                      double cobrado = ventasDia.where((v) => v['pagado'] == true).fold(0, (s, v) => s + (v['monto'] ?? 0));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _etiquetaFecha(fechaHeader),
                          ...ventasDia.map((v) => _tarjetaVenta(v)).toList(),
                          _panelResumen(total, cobrado, total - cobrado),
                          const SizedBox(height: 25),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _tarjetaVenta(Map<String, dynamic> venta) {
    bool pagado = venta['pagado'] ?? false;
    bool entregado = venta['entregado'] ?? false;
    String fechaCompleta = venta['fecha'] ?? "";
    String hora = fechaCompleta.contains(" - ") ? fechaCompleta.split(" - ")[1] : "";

    String nombreDistrito = _limpiarDistrito(venta['distrito']);

    String detalle = (venta['productos'] != null && (venta['productos'] as List).isNotEmpty)
        ? (venta['productos'] as List).map((p) => "${p['cantidad']} ${p['producto']}").join(", ")
        : venta['detalle'] ?? "Sin detalle";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _mostrarOpciones(venta),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venta['cliente'] ?? "Cliente", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                        ),
                        Text(
                          "${hora.isNotEmpty ? '$hora | ' : ''}$nombreDistrito", 
                          style: TextStyle(
                            color: Colors.teal[700], 
                            fontSize: 11, 
                            fontWeight: FontWeight.w500
                          )
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "S/. ${venta['monto']?.toStringAsFixed(2)}", 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[900])
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(detalle, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 2),
              const Divider(height: 24),
              Row(
                children: [
                  _badgeEstado(entregado ? "ENTREGADO" : "PENDIENTE", entregado ? Colors.blue : Colors.grey, Icons.local_shipping),
                  const SizedBox(width: 8),
                  _badgeEstado(pagado ? "PAGADO" : "DEBE", pagado ? Colors.green : Colors.redAccent, Icons.payments),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarOpciones(Map<String, dynamic> venta) {
    bool pagado = venta['pagado'] ?? false;
    bool entregado = venta['entregado'] ?? false;
    List productos = venta['productos'] ?? [];
    double totalMonto = (venta['monto'] ?? 0).toDouble();
    String fechaCompleta = venta['fecha'] ?? "Sin fecha";
    
    String nombreDistrito = _limpiarDistrito(venta['distrito']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 15),
            Text(venta['cliente'].toString().toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("$nombreDistrito - $fechaCompleta", style: TextStyle(color: Colors.teal[800], fontSize: 13, fontWeight: FontWeight.w500)),
            const Divider(height: 30),
            const Text("DETALLE DEL PEDIDO", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (productos.isNotEmpty)
              ...productos.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${p['cantidad']} de ${p['producto']}", style: const TextStyle(fontSize: 14)),
                        Text("S/. ${(p['subtotal'] ?? 0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )).toList()
            else
              Text(venta['detalle'] ?? "Sin detalles", style: const TextStyle(fontStyle: FontStyle.italic)),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("S/. ${totalMonto.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.teal[900])),
              ],
            ),
            const SizedBox(height: 25),
            ListTile(
              leading: Icon(entregado ? Icons.undo : Icons.check_circle, color: Colors.blue),
              title: Text(entregado ? "Desmarcar Entrega" : "Marcar como Entregado"),
              onTap: () {
                Navigator.pop(context);
                _update(venta, 'entregado');
              },
            ),
            ListTile(
              leading: Icon(pagado ? Icons.money_off : Icons.attach_money, color: Colors.green),
              title: Text(pagado ? "Desmarcar Pago" : "Marcar como Pagado"),
              onTap: () {
                Navigator.pop(context);
                _update(venta, 'pagado');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Eliminar Pedido"),
              onTap: () {
                Navigator.pop(context);
                _delete(venta);
              },
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---
  Widget _badgeEstado(String texto, Color color, IconData icono) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Row(children: [Icon(icono, size: 12, color: color), const SizedBox(width: 4), Text(texto, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))]));
  Widget _panelResumen(double total, double cobrado, double deuda) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.teal[900], borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_datoResumen("TOTAL", total, Colors.white), _datoResumen("COBRADO", cobrado, Colors.greenAccent), _datoResumen("DEUDA", deuda, Colors.orangeAccent)]));
  Widget _datoResumen(String label, double valor, Color color) => Column(children: [Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)), Text("S/. ${valor.toStringAsFixed(1)}", style: TextStyle(color: color, fontWeight: FontWeight.bold))]);
  
  Widget _etiquetaFecha(String fecha) => Padding(
    padding: const EdgeInsets.only(top: 15, bottom: 10), 
    child: Text(
      fecha.toUpperCase(), 
      style: TextStyle(color: Colors.teal[900], fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2)
    )
  );
  
  Widget _estadoVacio(String msg) => Center(child: Text(msg));

  // ================= SELECCIONAR FECHA MODIFICADA (LIMA, PERÚ) =================
 Future<void> _seleccionarFecha() async {
  DateTime? fecha = await showDatePicker(
    context: context, 
    initialDate: DateTime.now(), 
    firstDate: DateTime(2023), 
    lastDate: DateTime.now(), 
    locale: const Locale("es", "PE"), 
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.light(primary: Colors.teal[800]!)
      ), 
      child: child!
    )
  );

  if (fecha != null) {
    setState(() {
      _fechaSeleccionada = fecha;
      _estaCargando = true;
      _pedidosCargados.clear();
      _searchController.clear(); 
    });

    // IMPORTANTE: Usamos un formato que no dependa de tildes en los días (lunes, miércoles, etc.)
    // Buscamos solo el "corazón" de la fecha que está en tu BD: "31 ene. 2026"
    String fechaQuery = DateFormat("d MMM. yyyy", 'es_PE').format(fecha);
    
    print("DEBUG: Buscando en MongoDB con el texto: $fechaQuery");

    final resultados = await MongoService.getVentasPorFecha(fechaQuery);

    setState(() {
      _pedidosCargados = resultados;
      _estaCargando = false;
      _hayMasPedidos = false; // Desactivamos paginación infinita durante el filtro
    });
  }
}
}