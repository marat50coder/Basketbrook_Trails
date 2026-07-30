import 'dart:convert';

import '../config/trail_gate_config.dart';
import '../core/gate_models.dart';
import 'trail_agent.dart';
import 'trail_attribution.dart';
import 'trail_vault.dart';

/// Talks to the config endpoint and caches accepted destinations. Every
/// failure is folded into a rejected [GateReply] so the coordinator can
/// treat "no reply" like an unattributed install.
class GateExchange {
  GateExchange(this._agent, this._vault);

  static const Duration _requestBudget = Duration(seconds: 15);
  static const Map<String, String> _jsonHeaders = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  final TrailAgent _agent;
  final TrailVault _vault;

  Future<GateReply> request(Map<String, dynamic> payload) async {
    if (!TrailGateConfig.grayCredentialsReady) {
      return GateReply.rejected('credentials_unavailable');
    }

    final body = jsonEncode(payload);
    trailTrace(() => '[BB.EXCHANGE] request $body');

    final Uri endpoint;
    try {
      endpoint = Uri.parse(TrailGateConfig.endpoint);
    } catch (error) {
      trailTrace(() => '[BB.EXCHANGE] bad endpoint: $error');
      return GateReply.rejected('invalid_endpoint');
    }

    try {
      final response = await _agent
          .post(endpoint, headers: _jsonHeaders, body: body)
          .timeout(_requestBudget);

      trailTrace(
        () => '[BB.EXCHANGE] response ${response.statusCode} ${response.body}',
      );

      if (response.statusCode != 200) {
        return GateReply.rejected('http_${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return GateReply.rejected('invalid_response');

      final reply = GateReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      trailTrace(() => '[BB.EXCHANGE] failed: $error');
      return GateReply.rejected('network_failure');
    }
  }
}
