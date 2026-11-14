import 'package:flutter/services.dart';

/// Pide la huella, el PIN o el patrón del teléfono antes de algo delicado
/// (por ejemplo, borrar la clave de la IA). Si el teléfono no tiene bloqueo
/// puesto, deja seguir. Devuelve si se confirmó.
Future<bool> confirmIdentity({
  String title = 'Confirmá que sos vos',
  String detail = '',
}) async {
  try {
    return await const MethodChannel('recordame/identidad').invokeMethod<bool>(
          'confirmar',
          {'titulo': title, 'detalle': detail},
        ) ??
        // Sin respuesta: no hay quien atienda (fuera del teléfono).
        true;
  } on MissingPluginException {
    // Fuera del teléfono (pruebas): no hay bloqueo que pedir.
    return true;
  } catch (_) {
    return false;
  }
}
