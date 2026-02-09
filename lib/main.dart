import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Librería para idiomas
import 'mongo_service.dart'; 
import 'vistas/nueva_venta.dart';
import 'vistas/pedidos.dart';
import 'vistas/chat_ia.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
void main() async {
  // Asegura que los widgets carguen primero
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('cache_box');
  await dotenv.load(fileName: ".env"); // Abrimos un "cajón" para los datos
  runApp(const AppVentasPremium());

  // 2. Conectamos a Mongo en segundo plano (sin 'await')
  MongoService.connect().then((_) {
    print("✅ Conexión establecida en segundo plano");
  }).catchError((e) {
    print("❌ Falló la conexión: $e");
  });
}

class AppVentasPremium extends StatelessWidget {
  const AppVentasPremium({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // --- CONFIGURACIÓN DE IDIOMA ESPAÑOL ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
      ],
      // ---------------------------------------
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          primary: const Color(0xFF00695C),
        ),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0;

 final List<Widget> _paginas = [
  const VentanaHomeCompleta(),
  const VentanaPedidos(),
  const VentanaChatIA(), // <--- Cambiamos VentanaHistorial por esta
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      extendBody: true,
      body: _paginas[_indiceActual],
      bottomNavigationBar: _construirBarraNavegacion(),
    );
  }

  // (El resto de tu código de la barra de navegación se mantiene igual...)
  Widget _construirBarraNavegacion() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 65,
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _itemBarra(0, Icons.add_box_rounded),
                _itemBarra(1, Icons.inventory_2_rounded),
                _itemBarra(2, Icons.chat_rounded)
              ],
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            alignment: Alignment(_indiceActual == 0 ? -0.85 : (_indiceActual == 1 ? 0.0 : 0.85), 0),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 25),
              child: Container(
                height: 65,
                width: 65,
                decoration: BoxDecoration(
                  color: const Color(0xFF00695C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  _indiceActual == 0 ? Icons.add_box_rounded :
                  _indiceActual == 1 ? Icons.inventory_2_rounded : Icons.chat_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemBarra(int index, IconData icon) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _indiceActual = index),
        child: SizedBox(
          height: 65,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _indiceActual == index ? 0 : 1,
              child: Icon(icon, color: Colors.grey.shade400, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}