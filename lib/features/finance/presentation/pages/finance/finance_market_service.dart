// ============================================================================
// FILE: lib/features/finance/presentation/pages/finance/finance_market_service.dart
//
// Serviço leve para buscar indicadores macro usados na área Investir.
//
// O que este arquivo faz:
// - Busca Selic anualizada e IPCA acumulado em 12 meses.
// - Usa endpoints públicos do Banco Central do Brasil.
// - Não depende de integração bancária nem de pacote HTTP externo.
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
      return FinanceMarketSnapshot(
        selicAnnual: selicAnnual,
        ipca12Months: ipca12Months,
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
    return _parseBrazilNumber(value);
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
          (item) => _parseBrazilNumber(
            (item as Map<String, dynamic>)['valor']?.toString(),
          ),
        )
        .toList();
  }

  double _compoundMonthlyRates(List<double> monthlyRates) {
    double factor = 1;
    for (final rate in monthlyRates) {
      factor *= (1 + (rate / 100));
    }
    return ((factor - 1) * 100);
  }

  double _parseBrazilNumber(String? value) {
    final normalized = (value ?? '0')
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }
}
