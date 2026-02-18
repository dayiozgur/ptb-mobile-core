import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'team_model.dart';

/// Team Service
///
/// Takim yonetimi saglar. CRUD operasyonlari ve
/// uye yonetimi islemleri.
class TeamService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Team listesi stream
  final _teamsController = StreamController<List<Team>>.broadcast();

  /// Mevcut tenant ID
  String? _currentTenantId;

  /// Mevcut team listesi
  List<Team> _teams = [];

  /// Cache TTL
  static const _cacheTtl = Duration(minutes: 10);

  TeamService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Team listesi stream
  Stream<List<Team>> get teamsStream => _teamsController.stream;

  /// Mevcut team listesi
  List<Team> get teams => List.unmodifiable(_teams);

  /// Aktif takimlar
  List<Team> get activeTeams =>
      _teams.where((t) => t.isActive).toList();

  // ============================================
  // CONTEXT
  // ============================================

  /// Tenant context ayarla
  void setTenant(String tenantId) {
    if (_currentTenantId != tenantId) {
      _currentTenantId = tenantId;
      _teams = [];
      _teamsController.add(_teams);
    }
  }

  /// Context temizle
  void clearContext() {
    _currentTenantId = null;
    _teams = [];
    _teamsController.add(_teams);
  }

  // ============================================
  // TEAM OPERATIONS
  // ============================================

  /// Takimlari getir
  Future<List<Team>> getTeams({bool forceRefresh = false}) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    final cacheKey = 'teams_$_currentTenantId';

    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          _teams = cached
              .map((e) => Team.fromJson(e as Map<String, dynamic>))
              .toList();
          _teamsController.add(_teams);
          return _teams;
        } catch (cacheError) {
          Logger.warning('Failed to parse teams from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      final response = await _supabase
          .from('teams')
          .select('*, team_staffs(staff_id)')
          .or('tenant_id.eq.$_currentTenantId,tenant_id.is.null')
          .order('name');

      final responseList = response as List;

      Logger.debug('Teams query returned ${responseList.length} records');

      _teams = responseList
          .map((e) => Team.fromJson(e as Map<String, dynamic>))
          .toList();

      await _cacheManager.set(cacheKey, responseList, ttl: _cacheTtl);

      _teamsController.add(_teams);
      return _teams;
    } catch (e) {
      Logger.error('Error fetching teams: $e');
      rethrow;
    }
  }

  /// Tek takim getir
  Future<Team?> getTeam(String id) async {
    try {
      final response = await _supabase
          .from('teams')
          .select('*, team_staffs(staff_id)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Team.fromJson(response);
    } catch (e) {
      Logger.error('Error fetching team: $e');
      rethrow;
    }
  }

  /// Takim olustur
  Future<Team> createTeam({
    required String name,
    String? code,
    String? description,
    bool? independent,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    try {
      final data = {
        'name': name,
        'code': code,
        'description': description,
        'tenant_id': _currentTenantId,
        'independent': independent,
        'active': true,
      };

      final response = await _supabase
          .from('teams')
          .insert(data)
          .select('*, team_staffs(staff_id)')
          .single();

      final team = Team.fromJson(response);

      _teams.add(team);
      _teamsController.add(_teams);

      await _invalidateCache();

      Logger.info('Created team: ${team.id}');
      return team;
    } catch (e) {
      Logger.error('Error creating team: $e');
      rethrow;
    }
  }

  /// Takim guncelle
  Future<Team> updateTeam(
    String id, {
    String? name,
    String? code,
    String? description,
    bool? active,
    bool? independent,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) data['name'] = name;
      if (code != null) data['code'] = code;
      if (description != null) data['description'] = description;
      if (active != null) data['active'] = active;
      if (independent != null) data['independent'] = independent;

      final response = await _supabase
          .from('teams')
          .update(data)
          .eq('id', id)
          .select('*, team_staffs(staff_id)')
          .single();

      final team = Team.fromJson(response);

      final index = _teams.indexWhere((t) => t.id == id);
      if (index >= 0) {
        _teams[index] = team;
        _teamsController.add(_teams);
      }

      await _invalidateCache();

      Logger.info('Updated team: $id');
      return team;
    } catch (e) {
      Logger.error('Error updating team: $e');
      rethrow;
    }
  }

  /// Takim sil (soft delete)
  Future<void> deleteTeam(String id) async {
    try {
      await _supabase
          .from('teams')
          .update({
            'active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      _teams.removeWhere((t) => t.id == id);
      _teamsController.add(_teams);

      await _invalidateCache();

      Logger.info('Deleted team: $id');
    } catch (e) {
      Logger.error('Error deleting team: $e');
      rethrow;
    }
  }

  // ============================================
  // MEMBER OPERATIONS
  // ============================================

  /// Takim uyelerini getir
  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    try {
      final response = await _supabase
          .from('team_staffs')
          .select('*, staffs(name, email)')
          .eq('team_id', teamId);

      return (response as List)
          .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching team members: $e');
      rethrow;
    }
  }

  /// Takima uye ekle
  Future<TeamMember> addTeamMember({
    required String teamId,
    required String staffId,
  }) async {
    try {
      final response = await _supabase
          .from('team_staffs')
          .insert({
            'team_id': teamId,
            'staff_id': staffId,
            'active': true,
          })
          .select('*, staffs(name, email)')
          .single();

      await _invalidateCache();

      Logger.info('Added member $staffId to team $teamId');
      return TeamMember.fromJson(response);
    } catch (e) {
      Logger.error('Error adding team member: $e');
      rethrow;
    }
  }

  /// Takimdan uye cikar
  Future<void> removeTeamMember({
    required String teamId,
    required String staffId,
  }) async {
    try {
      await _supabase
          .from('team_staffs')
          .delete()
          .eq('team_id', teamId)
          .eq('staff_id', staffId);

      await _invalidateCache();

      Logger.info('Removed member $staffId from team $teamId');
    } catch (e) {
      Logger.error('Error removing team member: $e');
      rethrow;
    }
  }

  /// Personelin ait oldugu takimlari getir
  Future<List<Team>> getTeamsForStaff(String staffId) async {
    try {
      final response = await _supabase
          .from('team_staffs')
          .select('team_id, teams(*)')
          .eq('staff_id', staffId);

      final data = response as List;

      return data
          .where((e) => e['teams'] != null)
          .map((e) => Team.fromJson(e['teams'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching teams for staff: $e');
      rethrow;
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  Future<void> _invalidateCache() async {
    if (_currentTenantId != null) {
      await _cacheManager.deleteWhere(
        (key) => key.startsWith('teams_$_currentTenantId'),
      );
    }
  }

  /// Temizle
  void dispose() {
    _teamsController.close();
  }
}
