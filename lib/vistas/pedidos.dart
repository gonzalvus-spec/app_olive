import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../mongo_service.dart';

class VentanaPedidos extends StatefulWidget {
  const VentanaPedidos({super.key});

  @override
  State<VentanaPedidos> createState() => _VentanaPedidosState();
}

class _VentanaPedidosState extends State<VentanaPedidos> {
  // --- Variables para Paginación ---
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _pedidosCargados = [];
  bool _estaCargando = false;
  bool _hayMasPedidos = true;
  final int _cantidadPorPagina = 15;

  DateTime? _fechaSeleccionada;

  @override
  void initState() {
    super.initState();
    _cargarSiguientePagina(); // Carga inicial
    
    // Escuchar el scroll para cargar más cuando llegue al final
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_estaCargando &&
          _hayMasPedidos &&
          _fechaSeleccionada == null) {
        _cargarSiguientePagina();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ================= CARGA DE DATOS (PAGINACIÓN) =================
  Future<void> _cargarSiguientePagina() async {
    if (_estaCargando) return;

    setState(() => _estaCargando = true);

    // Llamamos al servicio con skip (cuántos ya tenemos) y limit
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

  // Función para refrescar la lista (Pull to refresh)
  Future<void> _refrescarLista() async {
    setState(() {
      _pedidosCargados.clear();
      _hayMasPedidos = true;
      _fechaSeleccionada = null; // Al refrescar quitamos filtros
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

  // ================= LÓGICA DE FILTRADO Y AGRUPACIÓN =================
  Map<String, List<Map<String, dynamic>>> _agruparPorFecha(List<Map<String, dynamic>> ventas) {
    Map<String, List<Map<String, dynamic>>> grupos = {};
    for (var v in ventas) {
      String fechaCompleta = v['fecha'] ?? "Sin Fecha";
      String soloFecha = fechaCompleta.contains(" - ") ? fechaCompleta.split(" - ")[0] : fechaCompleta;
      if (!grupos.containsKey(soloFecha)) grupos[soloFecha] = [];
      grupos[soloFecha]!.add(v);
    }
    return grupos;
  }

  List<Map<String, dynamic>> _filtrarPorFecha(List<Map<String, dynamic>> ventas) {
    // Nota: El filtrado ahora se hace principalmente en el servidor al seleccionar fecha,
    // pero mantenemos esta lógica por seguridad si hubiera datos locales.
    if (_fechaSeleccionada == null) return ventas;
    String fechaBuscada = DateFormat("dd MMM. yyyy", 'es_ES').format(_fechaSeleccionada!).toLowerCase();
    return ventas.where((v) {
      String fechaDB = v['fecha']?.toString().toLowerCase() ?? "";
      return fechaDB.contains(fechaBuscada);
    }).toList();
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
        Navigator.pop(context);
        _refrescarLista(); // Recargar para ver cambios
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
        Navigator.pop(context);
        _refrescarLista();
      }
    }
  }

  // ================= UI PRINCIPAL =================
  @override
  Widget build(BuildContext context) {
    final ventasFiltradas = _filtrarPorFecha(_pedidosCargados);
    final ventasAgrupadas = _agruparPorFecha(ventasFiltradas);
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
          if (_fechaSeleccionada != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off, color: Colors.orangeAccent), 
              onPressed: () => _refrescarLista()
            ),
        ],
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

    String detalle = (venta['productos'] != null && (venta['productos'] as List).isNotEmpty)
        ? (venta['productos'] as List).map((p) => "${p['cantidad']} ${p['producto']}").join(", ")
        : venta['detalle'] ?? "Sin detalle";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
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
                        Text(venta['cliente'] ?? "Cliente", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (hora.isNotEmpty) Text(hora, style: TextStyle(color: Colors.teal[700], fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Text("S/. ${venta['monto']?.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[900])),
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
            Text(fechaCompleta, style: TextStyle(color: Colors.teal[800], fontSize: 13, fontWeight: FontWeight.w500)),
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
              onTap: () => _update(venta, 'entregado'),
            ),
            ListTile(
              leading: Icon(pagado ? Icons.money_off : Icons.attach_money, color: Colors.green),
              title: Text(pagado ? "Desmarcar Pago" : "Marcar como Pagado"),
              onTap: () => _update(venta, 'pagado'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Eliminar Pedido"),
              onTap: () => _delete(venta),
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
  Widget _etiquetaFecha(String fecha) => Padding(padding: const EdgeInsets.only(top: 10, bottom: 10), child: Text(fecha.toUpperCase(), style: TextStyle(color: Colors.teal[900], fontWeight: FontWeight.bold, fontSize: 13)));
  Widget _estadoVacio(String msg) => Center(child: Text(msg));

  Future<void> _seleccionarFecha() async {
    DateTime? fecha = await showDatePicker(
      context: context, 
      initialDate: DateTime.now(), 
      firstDate: DateTime(2023), 
      lastDate: DateTime.now(), 
      locale: const Locale("es", "ES"), 
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Colors.teal[800]!)), child: child!)
    );

    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
        _estaCargando = true;
        _pedidosCargados.clear(); // Limpiamos para mostrar solo el resultado del filtro
      });

      // Formateamos para la búsqueda en MongoDB
      String fechaQuery = DateFormat("dd MMM. yyyy", 'es_ES').format(fecha).toLowerCase();
      
      // Llamada al nuevo método del servicio
      final resultados = await MongoService.getVentasPorFecha(fechaQuery);

      setState(() {
        _pedidosCargados = resultados;
        _estaCargando = false;
        _hayMasPedidos = false; // Desactivamos carga infinita durante el filtro
      });
    }
  }
}