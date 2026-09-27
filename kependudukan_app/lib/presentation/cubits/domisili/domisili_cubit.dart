import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ladimas/data/models/family_member_model.dart';
import 'package:ladimas/domain/repositories/family_repository.dart';
import 'package:latlong2/latlong.dart';

import 'package:ladimas/domain/repositories/auth_repository.dart';

part 'domisili_state.dart';

class DomisiliCubit extends Cubit<DomisiliState> {
  final FamilyRepository repository;
  final AuthRepository authRepository;

  final Map<String, FamilyMemberModel> _memberCache = {};
  final Map<String, DateTime> _memberCacheTimestamp = {};
  final Duration _cacheDuration = const Duration(minutes: 15);

  DomisiliCubit({
    required this.repository,
    required this.authRepository,
  }) : super(DomisiliInitial());

  Future<void> loadFamilyMember(String kk, String nik,
      {bool forceRefresh = false}) async {
    if (state is DomisiliLoading) return;

    if (!forceRefresh) {
      final cachedMember = _getCachedMember(nik);
      if (cachedMember != null) {
        emit(DomisiliLoaded(member: cachedMember));
        return;
      }
    }

    emit(DomisiliLoading());

    // 1. Fetch family members from Go API (official data)
    final familyResult =
        await repository.getFamilyMembers(kk, forceRefresh: forceRefresh);

    // 2. Fetch user profile from Laravel API (domicile data)
    final profileResult = await authRepository.getUserProfile();

    familyResult.fold(
      (failure) => emit(DomisiliError(message: failure.message)),
      (members) {
        try {
          var member = members.firstWhere((m) => m.nik == nik);

          // Create a mutable JSON map for deep merging
          final Map<String, dynamic> mergedJson = member.toJson();

          // Merge with domicile data from profile if available
          profileResult.fold(
            (_) => null, // Ignore profile error, use official data
            (profile) {
              // AuthRepository returns the 'data' part of the response already, 
              // but we'll check for both just in case the structure varies
              final user = (profile.containsKey('data') && profile['data'] is Map) 
                ? profile['data'] as Map<String, dynamic>
                : profile;
              
              if (user != null && user.isNotEmpty) {
                final String userNikStr = user['nik']?.toString() ?? '';
                // Check if target member is the user themselves
                if (userNikStr == nik) {
                  mergedJson.addAll(user);
                } else {
                  // Check in family_members from profile
                  final familyMembers = user['family_members'] as List?;
                  if (familyMembers != null) {
                    final profileMember = familyMembers.firstWhere(
                      (m) => m['nik']?.toString() == nik,
                      orElse: () => null,
                    );

                    if (profileMember != null) {
                      mergedJson.addAll(profileMember);
                    }
                  }
                }
              }
            },
          );

          // Re-parse the merged data to apply correctly prioritized selection
          member = FamilyMemberModel.fromJson(mergedJson);

          _memberCache[nik] = member;
          _memberCacheTimestamp[nik] = DateTime.now();

          emit(DomisiliLoaded(member: member));
        } catch (e) {
          emit(const DomisiliError(message: 'Member not found'));
        }
      },
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  FamilyMemberModel? _getCachedMember(String nik) {
    if (_memberCache.containsKey(nik) &&
        _memberCacheTimestamp.containsKey(nik)) {
      final timestamp = _memberCacheTimestamp[nik]!;
      final now = DateTime.now();
      if (now.difference(timestamp) < _cacheDuration) {
        return _memberCache[nik];
      }
    }
    return null;
  }

  Future<void> updateCoordinate(String nik, LatLng position) async {
    if (state is DomisiliLoading) return;

    final coordinate = "${position.latitude},${position.longitude}";
    emit(DomisiliUpdating(
        member:
            state is DomisiliLoaded ? (state as DomisiliLoaded).member : null));

    final result =
        await repository.updateFamilyMemberCoordinate(nik, coordinate);

    result.fold((failure) => emit(DomisiliError(message: failure.message)),
        (success) {
      if (success && state is DomisiliLoaded) {
        final currentMember = (state as DomisiliLoaded).member;
        final updatedMember = currentMember.copyWith(coordinate: coordinate);

        _memberCache[nik] = updatedMember;
        _memberCacheTimestamp[nik] = DateTime.now();

        emit(DomisiliLoaded(member: updatedMember));
      }
    });
  }

  void clearCache() {
    _memberCache.clear();
    _memberCacheTimestamp.clear();
  }
}
