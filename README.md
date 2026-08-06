# Lumière & Co. — PyME-Sync

Aplicación móvil/web para la gestión de una PyME de velas artesanales: catálogo e inventario de productos, ventas, usuarios con roles y reportes, construida en Flutter con Firebase como backend.

## Stack

- **Flutter** (web, con soporte Android) — UI, navegación y lógica de negocio.
- **Firebase Auth** — autenticación por correo y contraseña. Los usuarios nuevos se crean con una cuenta de Auth real desde el panel de Usuarios (ver `usuarios.dart`).
- **Cloud Firestore** — persistencia de productos, usuarios y ventas en tiempo real (`StreamBuilder`), protegida con reglas de seguridad basadas en rol (`firestore.rules`).
- **Firebase Storage** — almacenamiento de imágenes de producto, protegido con `storage.rules`.
- Proyecto de Firebase activo: **`lumiere-velas`**.

## Estructura

El código de la app vive en [lumiere-app/mi_app](lumiere-app/mi_app):

```
lumiere-app/mi_app/lib/
├── main.dart          # Login (detecta el rol y decide esAdmin) y arranque de la app
├── inventario.dart    # Shell de navegación + catálogo/CRUD de productos
├── usuarios.dart       # Gestión de usuarios y creación de cuentas de Auth
├── ventas.dart         # Registro de ventas (descuenta stock vía transacción)
├── reportes.dart       # Dashboard de KPIs, gráfica e historial (datos reales de `ventas`)
└── firebase_options.dart

lumiere-app/mi_app/
├── firestore.rules     # Reglas de acceso por rol para Firestore
└── storage.rules        # Reglas de acceso para Storage
```

### Roles

En el login (`main.dart`) se consulta `usuarios/{uid}` en Firestore y se calcula `esAdmin` a partir del campo `rol`/`role`. Ese valor se pasa a `InventarioPage(esAdmin: ...)`, que oculta "Usuarios" y "Reportes" del menú para cualquier rol que no sea Administrador. "Ventas" y "Catálogo" son visibles para todos. Al dar de alta un usuario desde el panel de Usuarios se crea también su cuenta real de Firebase Auth, con el documento de Firestore usando ese mismo UID como ID — así el login puede encontrar su rol de forma confiable.

## Correr en local

```bash
cd lumiere-app/mi_app
flutter pub get
flutter run -d chrome     # o -d <dispositivo> para Android
```

## Tests y análisis estático

```bash
cd lumiere-app/mi_app
flutter analyze
flutter test
```

## Desplegar reglas de seguridad

Las reglas viven en el repo pero deben publicarse por separado con Firebase CLI (requiere acceso al proyecto `lumiere-velas`):

```bash
cd lumiere-app/mi_app
firebase deploy --only firestore:rules,storage:rules
```

## Despliegue web

El build de producción ya no se comitea en la raíz del repositorio; se publica desde la rama `gh-pages`. Ver esa rama para el flujo de despliegue actual.

## Estado conocido / próximos pasos

- Eliminar un usuario borra su acceso a nivel de la app (documento en Firestore), pero no su cuenta de Firebase Auth: eso requeriría Admin SDK desde un backend (p. ej. Cloud Functions), fuera del alcance de una app 100% cliente.
- El filtro temporal de Reportes ("Esta Semana" / "Este Mes" / "Este Año") todavía no filtra los datos mostrados.
- El login tiene un atajo de compatibilidad (si el correo contiene "admin" se otorga acceso de Administrador aunque no haya rol en Firestore); es solo un respaldo del lado del cliente, no afecta lo que permiten `firestore.rules`.
