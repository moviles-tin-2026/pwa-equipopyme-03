=== ERRORES ===

Archivo: reportes.dart
Módulo: Pantalla de reportes y rendimiento del negocio.

-Casting inseguro en lectura de Firestore

  Ubicación: _buildKpiCardsRow() $\rightarrow$ `StreamBuilder<QuerySnapshot>

  Gravedad: Alta (Crash en tiempo de ejecución)
 
  Al realizar la suma/filtrado de productos con stock bajo, el código asume implícitamente que la propiedad doc.data() no es nula, que la clave "stock" siempre existe en el documento y que viene con un tipo de dato estricto.
  
  Código Afectado:
    dart
  stockBajoCount = snapshot.data!.docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    return (data['stock'] ?? 0) < 5;
  }).length;

  Consecuencia:
  Si algún documento en la colección productos no contiene el campo stock definido, si el documento está nulo durante una lectura parcial, o si el tipo registrado no es compatible directamenete con la conversión explícita, la aplicación arrojará un error no controlado: TypeError: null is not a subtype of type Map<String, dynamic>.

-Incompatibilidad de API por Versión de SDK

  Ubicación: _buildGraficaVentasCard() y _buildMovimientosCard()

  Gravedad: Media-Alta (Error de compilación en versiones estables previas)

  Se utiliza el método de color withValues(alpha: ...) para aplicar transparencias.

  Código afectado: color: _Colors.brandLight.withValues(alpha: 0.15)

  Consecuencia:
  El método withValues fue introducido recientemente en Flutter 3.27+. Si el proyecto se compila en un entorno local, servidor de integración continua (CI/CD) o equipo de trabajo utilizando versiones previas (como Flutter 3.22 o 3.24), la compilación fallará al no reconocer dicho método.

-Riesgo de Desbordamiento de Pantalla en Móviles

  Ubicación: _buildKpiCardsRow()

Gravedad: Media (Defecto de UI / UX)

  Las tres tarjetas de métricas principales (Ingresos Totales, Pedidos Completados, Alertas de Stock) se encuentran contenidas dentro de una sola fila Row utilizando Expanded en cada elemento sin adaptación responsiva.

  Código afectado:

  Row(
  children: [
    Expanded(child: _KpiReportCard(...)),
    SizedBox(width: 16),
    Expanded(child: _KpiReportCard(...)),
    SizedBox(width: 16),
    Expanded(child: _KpiReportCard(...)),
   ],
  )

  Consecuencia:
  En dispositivos móviles con pantallas estrechas (ancho inferior a ~380px), el contenido de las tarjetas (textos, números e íconos) no dispondrá de suficiente espacio horizontal, provocando el error visual de franjas amarillas y negras.