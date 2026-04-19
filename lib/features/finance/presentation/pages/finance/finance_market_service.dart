// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance/finance_market_service.dart
//
// Serviço leve para buscar indicadores macro usados na área Investir.
// Ajuste desta versão:
// - Corrige a leitura de números brasileiros/ingleses da API.
// - Evita percentuais absurdos por erro de parsing.
// - Expõe CDI, Selic e IPCA 12 meses.
// - Se o CDI não puder ser carregado com segurança, usa a Selic como fallback.
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'finance_tab_models.dart';

class FinanceMarketService {
  Future<FinanceMarketSnapshot> loadBrazilSnapshot() async {
    final client = HttpClient();
    try {
      final selicAnnual = await _fetchLatestSgsValue(client, 1178);
      final ipcaMonthlyRates = await _fetchLatestSgsValues(client, 433, 12);
      final ipca12Months = _compoundMonthlyRates(ipcaMonthlyRates);

      double cdiAnnual = selicAnnual;
      try {
        // Em muitas leituras práticas de pós-fixados, CDI e Selic ficam muito próximos.
        // Se a série específica falhar, mantemos fallback seguro na Selic.
        cdiAnnual = await _fetchLatestSgsValue(client, 12);
        if (cdiAnnual <= 0 || cdiAnnual > 100) {
          cdiAnnual = selicAnnual;
        }
      } catch (_) {
        cdiAnnual = selicAnnual;
      }

      return FinanceMarketSnapshot(
        cdiAnnual: _sanitizeAnnualRate(cdiAnnual, fallback: selicAnnual),
        selicAnnual: _sanitizeAnnualRate(selicAnnual, fallback: 0),
        ipca12Months: _sanitizeAnnualRate(ipca12Months, fallback: 0),
        fetchedAt: DateTime.now(),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<double> _fetchLatestSgsValue(HttpClient client, int seriesCode) async {
    final uri = Uri.parse(
      'https://api.bcb.gov.br/dados/serie/bcdata.sgs.$seriesCode/dados/ultimos/1?formato=json',
    );
    final response = await (await client.getUrl(uri)).close();
    final body = await utf8.decoder.bind(response).join();
    final jsonBody = jsonDecode(body) as List<dynamic>;
    if (jsonBody.isEmpty) {
      throw StateError('Sem dados para a série $seriesCode.');
    }
    final value = (jsonBody.first as Map<String, dynamic>)['valor']?.toString();
    return _parseFlexibleNumber(value);
  }

  Future<List<double>> _fetchLatestSgsValues(
    HttpClient client,
    int seriesCode,
    int count,
  ) async {
    final uri = Uri.parse(
      'https://api.bcb.gov.br/dados/serie/bcdata.sgs.$seriesCode/dados/ultimos/$count?formato=json',
    );
    final response = await (await client.getUrl(uri)).close();
    final body = await utf8.decoder.bind(response).join();
    final jsonBody = jsonDecode(body) as List<dynamic>;
    if (jsonBody.isEmpty) {
      throw StateError('Sem dados para a série $seriesCode.');
    }
    return jsonBody
        .map(
          (item) => _parseFlexibleNumber(
            (item as Map<String, dynamic>)['valor']?.toString(),
          ),
        )
        .toList();
  }

  double _compoundMonthlyRates(List<double> monthlyRates) {
    double factor = 1.0;
    for (final rate in monthlyRates) {
      factor *= (1 + (rate / 100));
    }
    return (factor - 1) * 100;
  }

  double _parseFlexibleNumber(String? value) {
    final raw = (value ?? '0').trim();
    if (raw.isEmpty) return 0;

    // "14,65" -> 14.65
    if (raw.contains(',') && !raw.contains('.')) {
      return double.tryParse(raw.replaceAll(',', '.')) ?? 0;
    }

    // "1.234,56" -> 1234.56
    if (raw.contains(',') && raw.contains('.')) {
      final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0;
    }

    // "14.65" -> 14.65
    return double.tryParse(raw) ?? 0;
  }

  double _sanitizeAnnualRate(double value, {required double fallback}) {
    if (value.isNaN || value.isInfinite) return fallback;
    if (value < 0) return fallback;
    if (value > 1000) return fallback;
    return value;
  }
}
