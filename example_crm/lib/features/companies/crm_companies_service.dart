import 'package:protoolbag_core/protoolbag_core.dart';

import '../contacts/contacts_service.dart' show Contact;
import '../shared/crm_backend.dart';
import '../shared/crm_record.dart';

/// Firma 360'taki bir fırsat satırı (`fn_crm_account_360`).
class AccountDeal {
  final String id;
  final String subject;
  final String status;
  final num amount;
  final num probability;

  const AccountDeal({
    required this.id,
    this.subject = '',
    this.status = '',
    this.amount = 0,
    this.probability = 0,
  });

  /// RPC kolonları: `deal_id, subject, status, amount, probability`.
  factory AccountDeal.fromRow(Map<String, dynamic> r) => AccountDeal(
        id: r['deal_id']?.toString() ?? '',
        subject: (r['subject'] as String?) ?? '',
        status: (r['status'] as String?) ?? '',
        amount: crmNum(r['amount']) ?? 0,
        probability: crmNum(r['probability']) ?? 0,
      );
}

/// Firma 360 KPI'ları — web `CompanyDetailComponent.project` ile aynı formül:
/// açık = final-olmayan; ağırlıklı = Σ(tutar × olasılık/100) açıklarda;
/// kazanılan = `won` / `converted` (web ile birebir kod eşlemesi).
/// "Açık" kümesi web'deki sabit `won/lost/converted` listesi yerine
/// `status_definitions.is_final` ile belirlenir ([finalCodes]).
class AccountKpis {
  final num openPipeline;
  final num weighted;
  final num won;
  final int dealCount;

  const AccountKpis(this.openPipeline, this.weighted, this.won, this.dealCount);

  static const Set<String> wonCodes = {'won', 'converted'};

  factory AccountKpis.of(List<AccountDeal> deals, Set<String> finalCodes) {
    num open = 0, weighted = 0, won = 0;
    for (final d in deals) {
      final isOpen = !finalCodes.contains(d.status) &&
          !wonCodes.contains(d.status);
      if (isOpen) {
        open += d.amount;
        weighted += d.amount * d.probability / 100;
      }
      if (wonCodes.contains(d.status)) won += d.amount;
    }
    return AccountKpis(open, weighted, won, deals.length);
  }
}

/// Firma (company) okumaları — liste web `CompanyListComponent` (entity
/// engine `company`), 360 web `CompanyDetailComponent` (`fn_crm_account_360`
/// + `contacts.company_id`).
class CrmCompaniesService {
  CrmCompaniesService({CrmBackend? backend})
      : _backend = backend ?? SupabaseCrmBackend();

  final CrmBackend _backend;

  /// Firmanın fırsatları (`fn_crm_account_360(p_company_id)`) — hata fırlatır.
  Future<List<AccountDeal>> account360(String companyId) async {
    final rows = await _backend
        .rpcRows('fn_crm_account_360', {'p_company_id': companyId});
    return rows.map(AccountDeal.fromRow).where((d) => d.id.isNotEmpty).toList();
  }

  /// Firmaya bağlı kişiler; hata → boş (web `catchAsEmpty` ile aynı).
  Future<List<Contact>> contacts(String companyId) async {
    try {
      final rows = await _backend.contactsOfCompany(companyId);
      return rows.map(Contact.fromJson).toList();
    } catch (e) {
      Logger.error('crm company contacts hata', e);
      return const [];
    }
  }
}

/// Firma listesi arama süzgeci (ad / kod / şehir / sektör) — saf.
List<CrmRecord> filterCompanies(List<CrmRecord> all, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all;
  return all.where((c) {
    final hay = [
      c.subject ?? '',
      c.code ?? '',
      c.metaStr('city'),
      c.metaStr('sector'),
      c.metaStr('email'),
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }).toList();
}
