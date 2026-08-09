// Pruebas de widgets para LoginPage.
//
// Se prueba únicamente LoginPage (y no InventarioPage/UsuariosPage) porque
// esas pantallas dependen de FirebaseAuth/Firestore inicializados, lo cual
// no está disponible en el entorno de test sin mocks. La validación del
// formulario de login ocurre en el cliente (antes de llamar a Firebase),
// así que se puede probar de forma aislada y confiable.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mi_app/main.dart';

void main() {
  testWidgets('LoginPage muestra los campos de correo y contraseña', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('¡Bienvenido de vuelta!'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Muestra errores de validación si se envía el formulario vacío', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Por favor ingresa tu correo'), findsOneWidget);
    expect(find.text('Por favor ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('Muestra error si el correo no tiene un formato válido', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    await tester.enterText(find.byType(TextFormField).first, 'correo-invalido');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresa un correo válido'), findsOneWidget);
  });

  testWidgets('El ícono de contraseña alterna la visibilidad del texto', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });
}
