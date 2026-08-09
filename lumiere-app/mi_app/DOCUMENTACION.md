# Documentación técnica — Lumière & Co. PyME-Sync

> Este documento complementa a [README.md](README.md) (que cubre el quick-start) con el detalle técnico completo del proyecto: arquitectura, modelo de datos, permisos, cada pantalla, y el estado de despliegue. Está pensado para que cualquier integrante del equipo (o alguien nuevo) entienda el sistema completo sin tener que leer los cinco archivos de `lib/` uno por uno.

## Índice

1. [Resumen](#resumen)
2. [Stack tecnológico](#stack-tecnológico)
3. [Estructura del repositorio](#estructura-del-repositorio)
4. [Arquitectura de la app](#arquitectura-de-la-app)
5. [Modelo de datos (Firestore)](#modelo-de-datos-firestore)
6. [Roles y permisos](#roles-y-permisos)
7. [Reglas de seguridad](#reglas-de-seguridad)
8. [Pantallas y módulos](#pantallas-y-módulos)
9. [Sistema visual](#sistema-visual)
10. [Ejecución local](#ejecución-local)
11. [Tests y análisis estático](#tests-y-análisis-estático)
12. [Despliegue](#despliegue)
13. [Deuda técnica y limitaciones conocidas](#deuda-técnica-y-limitaciones-conocidas)

---

## Resumen

**Lumière & Co. — PyME-Sync** es una PWA (funciona también como app Android) para gestionar una pequeña empresa de velas artesanales: catálogo/inventario de productos, registro de ventas con descuento automático de stock, administración de usuarios con roles, y un dashboard de reportes con KPIs y gráfica de ingresos.

Es un proyecto universitario de equipo (ver commits de múltiples autores e `integrante1.md`), construido 100% del lado del cliente sobre Firebase — no hay backend propio.

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| UI / lógica | Flutter (Material 3), targets web y Android |
| Autenticación | Firebase Auth (email/contraseña) |
| Base de datos | Cloud Firestore (tiempo real vía `StreamBuilder`) |
| Archivos | Firebase Storage (imágenes de producto) |
| Gráficas | [`fl_chart`](https://pub.dev/packages/fl_chart) |
| Selección de archivos | [`file_picker`](https://pub.dev/packages/file_picker) |
| Proyecto Firebase | `lumiere-velas` |

Dependencias completas en [lumiere-app/mi_app/pubspec.yaml](lumiere-app/mi_app/pubspec.yaml).

## Estructura del repositorio

El repo tiene dos capas superpuestas que conviene no confundir:

```
pwa-equipopyme-03/
├── (raíz)                    # Build web de PRODUCCIÓN ya compilado
│   ├── main.dart.js, flutter_service_worker.js, manifest.json, ...
│   └── se sirve tal cual desde GitHub Pages / el hosting configurado
│
└── lumiere-app/mi_app/        # CÓDIGO FUENTE — aquí se trabaja
    ├── lib/
    │   ├── main.dart          # Login + arranque de la app
    │   ├── inventario.dart    # Shell de navegación + catálogo/CRUD de productos
    │   ├── usuarios.dart      # Gestión de usuarios y creación de cuentas Auth
    │   ├── ventas.dart        # Registro de ventas (descuenta stock vía transacción)
    │   ├── reportes.dart      # Dashboard de KPIs, gráfica e historial
    │   └── firebase_options.dart   # Config generada por FlutterFire CLI
    ├── firestore.rules        # Reglas de acceso por rol para Firestore
    ├── storage.rules          # Reglas de acceso para Storage
    ├── web/                   # Shell HTML/manifest de la PWA (index.html, manifest.json)
    ├── android/, ios/, macos/, linux/, windows/  # Proyectos nativos generados por Flutter
    └── pubspec.yaml           # Dependencias y assets (fuentes, imágenes)
```

**Importante:** los archivos compilados en la raíz del repo (`main.dart.js`, `flutter_service_worker.js`, etc.) son el resultado de `flutter build web` corrido sobre `lumiere-app/mi_app`. No se editan a mano — cualquier cambio de comportamiento debe hacerse en `lumiere-app/mi_app/lib/*.dart` y luego reconstruirse. En esta rama (`deploy/lighthouse-round-3`) el bundle de producción vive commiteado en la raíz para que GitHub Pages lo sirva directamente.

`integrante1.md` y `lumiere-app/mi_app/README.md` no son documentación de uso: son reportes de code review de integrantes del equipo (bugs encontrados en `reportes.dart` y `usuarios.dart` respectivamente). Su contenido relevante está incorporado en la sección [Deuda técnica](#deuda-técnica-y-limitaciones-conocidas) de este documento.

## Arquitectura de la app

- **Un solo `MaterialApp`**, sin paquete de rutas/router: la navegación entre Login → `InventarioPage` y entre secciones internas (Catálogo/Usuarios/Ventas/Reportes) se resuelve con `Navigator.pushReplacement` y con un `enum _NavSection` guardado en el estado de `InventarioPage` ([lumiere-app/mi_app/lib/inventario.dart](lumiere-app/mi_app/lib/inventario.dart)).
- **Carga diferida (`deferred as`)**: [main.dart](lumiere-app/mi_app/lib/main.dart) importa `inventario.dart` como `deferred`. Todo lo que cuelga de ahí (usuarios, ventas, reportes, Firebase Storage) no entra en el bundle inicial — se descarga con `inventario.loadLibrary()` recién cuando el login es exitoso. Es la optimización principal de tiempo de carga (ver `project_lighthouse_perf_ceiling` en el historial de commits `perf:`).
- **`InventarioPage` actúa como shell/router** de las 4 secciones post-login: renderiza sidebar + topbar comunes y hace `switch` sobre `_NavSection` para mostrar `_buildCatalogoSection()`, `UsuariosPage`, `VentasPage` o `ReportesPage`.
- **Estado**: todo es `StatefulWidget` + `setState`, sin gestor de estado externo (no hay Provider/Riverpod/Bloc). Los datos de Firestore se consumen con `StreamBuilder` (tiempo real) en cada pantalla.
- **Persistencia de sesión**: la maneja `firebase_auth` (Firebase Auth persiste la sesión en el navegador/dispositivo automáticamente); la app no guarda tokens propios.
- **Sin backend propio**: toda la lógica (incluida la creación de usuarios con Auth real, ver más abajo) corre en el cliente contra Firebase directamente, protegida por `firestore.rules` / `storage.rules`.

## Modelo de datos (Firestore)

Tres colecciones raíz:

### `usuarios/{uid}`
El ID del documento **es el mismo UID** de Firebase Auth del usuario (no un ID autogenerado) — así el login puede resolver el rol de un usuario buscando directamente por su UID.

| Campo | Tipo | Notas |
|---|---|---|
| `nombre` | string | |
| `email` | string | |
| `rol` | string | `Administrador` \| `Supervisor` \| `Operador` (ver [Roles y permisos](#roles-y-permisos)) |
| `activo` | bool | Solo informativo en la UI; no bloquea el login |
| `creadoEn` | Timestamp | |

### `productos/{id}` (ID autogenerado)

| Campo | Tipo | Notas |
|---|---|---|
| `nombre` | string | |
| `precio` | double | |
| `stock` | int | Se considera "stock bajo" si `< 5` (umbral hardcodeado en varias pantallas) |
| `categoria` | string | `Velas de Molde` \| `Velas en Vaso` \| `Wax Melts` \| `Accesorios` |
| `imageUrl` | string | URL de Firebase Storage; si está vacía, se usa una imagen local heurística por nombre (ver [`_ProductCard._localImagePathForProduct`](lumiere-app/mi_app/lib/inventario.dart)) o un ícono de categoría |
| `creadoEn` | Timestamp | Se usa para ordenar el catálogo (`orderBy('creadoEn', descending: true)`) |

### `ventas/{id}` (ID autogenerado, colección append-only)

| Campo | Tipo | Notas |
|---|---|---|
| `productoId` | string | referencia al doc de `productos` |
| `productoNombre` | string | copia desnormalizada, para no tener que hacer join al listar |
| `cantidad` | int | |
| `precioUnitario` | double | precio del producto al momento de la venta |
| `total` | double | `cantidad * precioUnitario` |
| `fecha` | Timestamp | |
| `vendedorEmail` | string | `FirebaseAuth.instance.currentUser?.email` |

## Roles y permisos

El login ([lumiere-app/mi_app/lib/main.dart](lumiere-app/mi_app/lib/main.dart)) lee `usuarios/{uid}.rol` (o `.role`) tras autenticar, y calcula un booleano `esAdmin` que se propaga a `InventarioPage(esAdmin: ...)`:

```dart
bool esAdmin = rolEncontrado.contains('admin') || rolEncontrado.contains('supervisor');
```

| Rol | Catálogo | Ventas | Usuarios | Reportes | Eliminar productos |
|---|:---:|:---:|:---:|:---:|:---:|
| Administrador | ✅ | ✅ | ✅ | ✅ | ✅ |
| Supervisor | ✅ | ✅ | ✅ | ✅ | ✅ |
| Operador (o sin rol) | ✅ | ✅ | ❌ | ❌ | ❌ |

- Administrador/Supervisor entran directo a la sección **Usuarios**; un Operador entra forzosamente a **Catálogo** (ver `initState` de `_InventarioPageState`).
- El sidebar oculta por completo las opciones "Usuarios" y "Reportes" para quien no es admin/supervisor — no es solo un disabled, el `_NavTile` ni se construye.
- El botón de eliminar producto (`onDelete`) solo se pasa al `_ProductCard` cuando `widget.esAdmin == true`; cualquier rol puede editar (`onEdit`).
- Esta lógica de UI es **solo una capa de conveniencia**: la autorización real la hacen `firestore.rules`, ver siguiente sección.

## Reglas de seguridad

### Firestore ([lumiere-app/mi_app/firestore.rules](lumiere-app/mi_app/firestore.rules))

- `tieneAccesoCompleto()` es la función central: busca `usuarios/{request.auth.uid}` y evalúa si el campo `rol` (o `role`) matchea `.*(admin|supervisor).*`, insensible a mayúsculas — coherente con la detección de `esAdmin` en `main.dart`.
- **`productos`**: lectura y creación/edición para cualquier autenticado; **borrado solo con acceso completo**.
- **`ventas`**: lectura y creación para cualquier autenticado; **update/delete deshabilitados siempre** (`if false`) — el historial de ventas es inmutable por diseño.
- **`usuarios`**: lectura para cualquier autenticado; creación permitida a quien tiene acceso completo, o a un usuario creando su propio documento (mismo UID, pensado para un futuro autoregistro que hoy no existe en la UI); update/delete solo con acceso completo.

### Storage ([lumiere-app/mi_app/storage.rules](lumiere-app/mi_app/storage.rules))

- `productos/{archivo}`: lectura para cualquier autenticado; escritura para cualquier autenticado siempre que el archivo pese menos de 5 MB y su `contentType` sea `image/*`.

Estas reglas viven en el repo pero **no se aplican solas** — hay que publicarlas explícitamente con el CLI de Firebase (ver [Despliegue](#despliegue)).

## Pantallas y módulos

### `main.dart` — Login
`LoginPage` es un formulario responsivo (layout distinto arriba/abajo de 600px de ancho) con imagen de marca (`VelasLogIn`, con blur "vidrio esmerilado" optimizado a `sigma: 5`). En `_handleLogin`:
1. `signInWithEmailAndPassword` contra Firebase Auth.
2. Lee `usuarios/{uid}` para determinar el rol.
3. Descarga el chunk diferido de `inventario.dart` (`inventario.loadLibrary()`) mientras el spinner del botón ya está visible, para no añadir una segunda espera perceptible.
4. Navega a `InventarioPage(esAdmin: ...)`, mostrando un `SnackBar` de bienvenida.

Existe un atajo legado: si el correo contiene la palabra "admin" se concede acceso de Administrador aunque no haya rol en Firestore. Es solo un respaldo del lado del cliente — no afecta lo que permiten las reglas de Firestore, así que no es un agujero de seguridad real, pero sí puede confundir a alguien que espera que el rol venga únicamente del documento.

### `inventario.dart` — Shell + Catálogo
- `InventarioPage`: `Scaffold` con `Drawer` (sidebar) configurado según `esAdmin`, `AppBar` con buscador/filtro/botón "Agregar producto" (solo visibles en la sección Catálogo), y el body que hace switch entre las 4 secciones.
- **Catálogo**: `StreamBuilder` sobre `productos` ordenado por `creadoEn`. KPIs (productos, unidades en stock, stock bajo), filtros por categoría/disponibilidad (bottom sheet) y búsqueda por nombre, todo aplicado client-side sobre el snapshot ya cargado (`_aplicarFiltros`). Grid responsivo por ancho de pantalla (2/3/4 columnas).
- **Alta de producto**: panel lateral deslizable (`AnimatedSize`) con formulario; sube la imagen a Storage (`productos/{timestamp}_{nombre}`) antes de crear el documento en Firestore, si se seleccionó una.
- **Edición de producto**: diálogo modal (`_mostrarDialogoEdicion`) con los mismos campos, permite reemplazar la imagen.
- **Tarjetas de producto** (`_ProductCard`): si `imageUrl` está vacía o falla la carga, hace fallback a una imagen local heurística según palabras clave en el nombre del producto (`_localImagePathForProduct`), y si esa también falla, a un ícono por categoría. Las imágenes de red se decodifican con `cacheWidth` acotado (optimización de memoria/CPU en el grid).

### `usuarios.dart` — Gestión de usuarios
- Solo alcanzable por Administrador/Supervisor (la navegación lo garantiza; no hay guard adicional en el widget).
- **Alta de usuario** (`_agregarUsuario`): el detalle más importante del módulo — crea la cuenta en una **instancia secundaria de `FirebaseApp`** (`Firebase.app('UsuarioSecundario')`). Esto es necesario porque `createUserWithEmailAndPassword` inicia sesión automáticamente con la cuenta recién creada en la instancia donde corre; usar una instancia secundaria evita cerrar la sesión del admin que está dando de alta al nuevo usuario. Tras crear la cuenta, hace `signOut()` en esa instancia secundaria y escribe el documento `usuarios/{uid}` (mismo UID que Auth) con nombre/email/rol/activo.
- **Baja de usuario**: borra solo el documento de Firestore (revoca acceso a nivel app), con confirmación previa (`_confirmarEliminacion`). **No borra la cuenta de Firebase Auth** — eso requeriría el Admin SDK desde un backend, fuera del alcance de una app 100% cliente (ver [Deuda técnica](#deuda-técnica-y-limitaciones-conocidas)).
- Lista con búsqueda por nombre/email/rol y KPIs (total, activos).

### `ventas.dart` — Registro de ventas
- Lista de las últimas 100 ventas (`limit(100)`) con KPIs (ventas registradas, ingresos totales).
- **`_registrarVenta`**: lo central del módulo. Envuelve la lectura del stock actual, la validación de stock suficiente, el descuento de stock y la creación del documento de venta en un único `runTransaction` — así dos ventas simultáneas del mismo producto no pueden dejar el stock en negativo (condición de carrera resuelta a nivel Firestore, no en el cliente).
- El formulario de venta calcula el total en vivo (`_totalCalculado`) y deshabilita/advierte si la cantidad supera el stock disponible del producto seleccionado.
- Expone `tiempoRelativo(DateTime)` (helper de formato "Hace 10 min" / "Ayer" / etc.) que también importa y reusa `reportes.dart`.

### `reportes.dart` — Dashboard / KPIs
- Trae hasta 300 ventas (`limit(300)`) y las filtra client-side por periodo (`_filtroTemporal`: Esta Semana / Este Mes / Este Año) en `_filtrarVentasPorPeriodo`.
- KPIs: ingresos totales, pedidos completados (ambos ya respetan el filtro temporal), y alertas de stock (stream aparte sobre `productos`, cuenta los que tienen `stock < 5` — este KPI **no** depende del filtro temporal, es siempre "ahora mismo").
- **Gráfica de ingresos** (`fl_chart`): la cantidad de puntos y sus etiquetas se adaptan al filtro seleccionado — 7 puntos (días de la semana) para "Esta Semana", N días del mes para "Este Mes", 12 meses para "Este Año" — reutilizando la misma función `indiceDe` para bucketear cada venta en su punto correspondiente.
- **Movimientos recientes**: las últimas 10 ventas del período filtrado.

## Sistema visual

Cada pantalla define su propia clase privada `_Colors` con la misma paleta (café/beige de marca):

| Token | Hex | Uso |
|---|---|---|
| `brand` | `#8C6239` | Color primario / acentos |
| `brandLight` | `#E2B28B` | Acentos secundarios |
| `bg` | `#FAF8F5` | Fondo general |
| `success` | `#556B2F` | Confirmaciones, ingresos, activo |
| `danger` | `#C97A7A` | Errores, stock bajo, eliminar |
| `textDark` / `textGray` | `#2D2D2D` / `#8E8E8E` | Texto primario/secundario |

Nota: `_Colors` (y `_KpiCard`) están **duplicados** en `inventario.dart`, `usuarios.dart` y `ventas.dart` en vez de vivir en un archivo compartido — es deuda de código intencionalmente fuera de alcance de este documento (ver [Deuda técnica](#deuda-técnica-y-limitaciones-conocidas)). Tipografía: Montserrat (variable font, ver [pubspec.yaml](lumiere-app/mi_app/pubspec.yaml)), Material 3 (`useMaterial3: true`).

## Ejecución local

```bash
cd lumiere-app/mi_app
flutter pub get
flutter run -d chrome     # o -d <dispositivo> para Android
```

Requiere acceso al proyecto Firebase `lumiere-velas` (la config ya está en `firebase_options.dart`, generado por FlutterFire CLI).

## Tests y análisis estático

```bash
cd lumiere-app/mi_app
flutter analyze
flutter test
```

El único test presente es el smoke test por defecto de Flutter ([lumiere-app/mi_app/test/widget_test.dart](lumiere-app/mi_app/test/widget_test.dart)) — no hay cobertura de la lógica de negocio (transacciones de venta, filtros, reglas de rol) más allá de eso.

## Despliegue

Dos piezas independientes:

**1. Build web** — se compila desde `lumiere-app/mi_app` y el resultado se commitea en la **raíz del repositorio** (rama `deploy/*` o `main`, según el flujo vigente) para que GitHub Pages lo sirva directamente. Los commits `deploy:` en el historial (`git log`) son exactamente eso: builds regenerados, no cambios de código fuente.

**2. Reglas de seguridad** — viven en el repo (`firestore.rules`, `storage.rules`) pero se publican aparte:

```bash
cd lumiere-app/mi_app
firebase deploy --only firestore:rules,storage:rules
```

Requiere acceso al proyecto `lumiere-velas` vía Firebase CLI. Un cambio en las reglas **no** se refleja en producción hasta correr este comando explícitamente.

## Deuda técnica y limitaciones conocidas

De `README.md` y de los reportes de code review del equipo (`integrante1.md`, `lumiere-app/mi_app/README.md`):

- **Eliminar un usuario no revoca su cuenta de Firebase Auth**, solo su documento en Firestore (pierde acceso a los datos protegidos por rol, pero la cuenta de Auth sigue existiendo). Solucionarlo requiere Admin SDK desde un backend (Cloud Functions), fuera del alcance de una app 100% cliente.
- **Casting inseguro al leer Firestore en `reportes.dart`** (`_buildKpiCardsRow`): asume que `doc.data()` nunca es nulo y castea directo a `Map<String, dynamic>` sin verificar. Si un documento de `productos` llegara sin el shape esperado, produciría un `TypeError` no controlado en tiempo de ejecución. El mismo patrón (`data['stock'] ?? 0`) se repite en varias pantallas — mitiga valores faltantes pero no tipos incorrectos.
- **Fila de KPIs sin adaptación a pantallas angostas**: tanto `_buildKpiCardsRow` en `reportes.dart` como la fila de KPIs de Catálogo en `inventario.dart` usan `Row` + `Expanded` fijos, sin envolver a columna en móvil. En pantallas muy angostas (<~380px) el contenido de las tarjetas puede desbordar. El commit `fe32b28` ("paneles de catálogo/usuarios/ventas responsivos en móvil") solo actualizó el **build compilado** en la raíz, sin cambios correspondientes en `lumiere-app/mi_app/lib/*.dart` — vale la pena confirmar que el fix de origen esté commiteado, o si se perdió en algún punto.
- **`activeColor` deprecado** en el `Switch.adaptive` de `usuarios.dart` — ya corregido a `activeThumbColor` en el código actual (el `README.md` del subproyecto seguía documentando el hallazgo original).
- **`_buildUsuariosSection` sin referenciar** en `usuarios.dart` (warning `unused_element` de `flutter analyze`) — código muerto a limpiar.
- El filtro temporal de Reportes (Esta Semana/Mes/Año) **sí filtra los datos** en el código actual (KPIs, gráfica e historial), a diferencia de lo que señala una versión anterior del `README.md` raíz — confirmar que ese punto del README esté actualizado.
- `_Colors` y `_KpiCard` están duplicados letra por letra en `inventario.dart`, `usuarios.dart` y `ventas.dart` en vez de extraerse a un archivo compartido (p. ej. `theme.dart` / `widgets_comunes.dart`).
- Sin tests más allá del smoke test por defecto — la lógica de transacción de venta, los filtros y las reglas de rol no tienen cobertura automatizada.