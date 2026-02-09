import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoService {
  static Db? db;
  static DbCollection? ventasCollection;
  static DbCollection? clientesCollection;
  static DbCollection? productosCollection;

  static final String mongoUrl = dotenv.env['MONGODB_URL'] ?? "";

  static Future<void> connect() async {
    if (mongoUrl.isEmpty) {
      print("❌ Error: No se encontró la URL de MongoDB en el archivo .env");
      return;
    }
    
    if (db != null && db!.isConnected) return;
    
    try {
      db = await Db.create(mongoUrl);
      await db!.open().timeout(const Duration(seconds: 10));
      
      ventasCollection = db!.collection("ventas");
      clientesCollection = db!.collection("clientes");
      productosCollection = db!.collection("productos");
      
      print("✅ Conexión segura establecida a MongoDB Atlas");
    } catch (e) {
      print("❌ Error de conexión: $e");
      db = null;
    }
  }

  // --- Función interna para normalizar distritos ---
  static String _normalizarDistrito(dynamic valor) {
    final String texto = (valor ?? "").toString().trim();
    if (texto.isEmpty || texto.toLowerCase() == "null") {
      return "DISTRITO";
    }
    return texto;
  }

  // ================= GESTIÓN DE VENTAS =================

  static Future<List<Map<String, dynamic>>> getVentas() async {
    if (ventasCollection == null) await connect();
    return await ventasCollection!.find(where.sortBy('createdAt', descending: true)).toList();
  }

  static Future<List<Map<String, dynamic>>> getVentasPaginadas(int skip, int limit) async {
    if (ventasCollection == null) await connect();
    try {
      return await ventasCollection!.find(
        where.sortBy('createdAt', descending: true)
             .skip(skip)
             .limit(limit)
      ).toList();
    } catch (e) {
      print("❌ Error en paginación: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getVentasPorNombre(String nombre) async {
    if (ventasCollection == null) await connect();
    try {
      return await ventasCollection!.find(
        where.match('cliente', '.*$nombre.*', caseInsensitive: true)
             .sortBy('createdAt', descending: true)
      ).toList();
    } catch (e) {
      print("❌ Error buscando por nombre: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getVentasPorDistrito(String distrito) async {
    if (ventasCollection == null) await connect();
    try {
      return await ventasCollection!.find(
        where.eq('distrito', distrito)
             .sortBy('createdAt', descending: true)
      ).toList();
    } catch (e) {
      print("❌ Error buscando por distrito: $e");
      return [];
    }
  }

  static Future<List<String>> getDistritosDeVentas() async {
    if (ventasCollection == null) await connect();
    try {
      final dynamic result = await ventasCollection!.distinct('distrito');
      if (result is List) {
        final listaLimpia = (result as List<dynamic>)
            .map((item) => _normalizarDistrito(item))
            .where((item) => item != "DISTRITO") // Opcional: filtrar el genérico
            .toSet()
            .toList();

        listaLimpia.sort();
        return listaLimpia;
      }
      return [];
    } catch (e) {
      print("❌ Error en getDistritosDeVentas: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getVentasPorFecha(String fechaBuscada) async {
    if (ventasCollection == null) await connect();
    try {
      return await ventasCollection!.find(
        where.match('fecha', '.*$fechaBuscada.*', caseInsensitive: true)
             .sortBy('createdAt', descending: true)
      ).toList();
    } catch (e) {
      print("❌ Error filtrando por fecha: $e");
      return [];
    }
  }

  static Future<void> insertVenta(Map<String, dynamic> data) async {
    if (ventasCollection == null) await connect();
    
    // Normalizar distrito antes de insertar
    data['distrito'] = _normalizarDistrito(data['distrito']);
    data['pagado'] = data['pagado'] ?? false;
    data['entregado'] = data['entregado'] ?? false;
    data['createdAt'] = data['createdAt'] ?? DateTime.now();
    
    await ventasCollection!.insert(data);
    print("✅ Venta guardada con éxito");
  }

  static Future<void> updateEstado(ObjectId id, String campo, bool valor) async {
    if (ventasCollection == null) await connect();
    await ventasCollection!.update(where.id(id), modify.set(campo, valor));
    print("✅ Estado $campo actualizado");
  }

  static Future<void> deleteVenta(ObjectId id) async {
    if (ventasCollection == null) await connect();
    await ventasCollection!.remove(where.id(id));
    print("✅ Venta eliminada");
  }

  // ================= GESTIÓN DE CLIENTES =================

  static Future<List<String>> getClientes() async {
    if (clientesCollection == null) await connect();
    final lista = await clientesCollection!.find(where.sortBy('nombre')).toList();
    return lista.map((c) => (c['nombre'] ?? "Sin nombre").toString()).toList();
  }

  static Future<List<Map<String, dynamic>>> getClientesData() async {
    if (clientesCollection == null) await connect();
    return await clientesCollection!.find(where.sortBy('nombre')).toList();
  }

  static Future<void> insertCliente(Map<String, dynamic> data) async {
    if (clientesCollection == null) await connect();
    
    // Normalizar distrito del cliente
    data['distrito'] = _normalizarDistrito(data['distrito']);
    data['createdAt'] = DateTime.now();
    
    await clientesCollection!.insert(data);
    print("✅ Cliente guardado");
  }

  // ================= GESTIÓN DE PRODUCTOS =================

  static Future<List<String>> getProductos() async {
    if (productosCollection == null) await connect();
    final lista = await productosCollection!.find(where.sortBy('nombre')).toList();
    return lista.map((p) => (p['nombre'] ?? "Producto").toString()).toList();
  }

  static Future<List<Map<String, dynamic>>> getProductosData() async {
    if (productosCollection == null) await connect();
    return await productosCollection!.find(where.sortBy('nombre')).toList();
  }

  static Future<void> insertProducto(Map<String, dynamic> data) async {
    if (productosCollection == null) await connect();
    data['createdAt'] = DateTime.now();
    await productosCollection!.insert(data);
    print("✅ Producto guardado");
  }
}