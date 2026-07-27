import 'dart:convert';

import '../config/trail_gate_config.dart';
import '../core/gate_models.dart';
import 'trail_attribution.dart';
import 'trail_agent.dart';
import 'trail_vault.dart';

class GateExchange {
  GateExchange(this._agent, this._vault);

  final TrailAgent _agent;
  final TrailVault _vault;

  Future<GateReply> request(Map<String, dynamic> payload) async {
    if (!TrailGateConfig.grayCredentialsReady) {
      return GateReply.rejected('credentials_unavailable');
    }
    try {
      trailTrace(() => '[BB.EXCHANGE] request ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(TrailGateConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
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
