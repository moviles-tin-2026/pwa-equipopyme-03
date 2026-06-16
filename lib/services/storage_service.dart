/// Contrato de API esperado por los screens — implementar en el equipo backend.
library;

import 'dart:typed_data';

abstract class StorageService {
  /// Sube imagen de producto y devuelve la URL pública.
  Future<String> uploadProductImage(String productId, Uint8List bytes);

  Future<void> deleteProductImage(String imageUrl);
}
