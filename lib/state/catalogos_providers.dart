// lib/state/catalogos_providers.dart
//
// Providers reactivos para los catálogos compartidos entre "Nueva
// venta" y la ficha de cliente. La consulta a Supabase vive en
// `CatalogosRepository`; aquí solo se expone como provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/catalogos_repository.dart';
import '../domain/models/catalogos.dart';

final _catalogosRepository = CatalogosRepository();

/// Condiciones de pago activas, para el desplegable de cabecera.
final condicionesPagoProvider = FutureProvider<List<CondicionPagoOption>>(
  (ref) => _catalogosRepository.obtenerCondicionesPago(),
);

/// Vendedores activos, para el desplegable de cabecera.
final vendedoresProvider = FutureProvider<List<VendedorOption>>(
  (ref) => _catalogosRepository.obtenerVendedores(),
);
