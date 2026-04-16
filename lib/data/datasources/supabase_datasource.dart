import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import '../../core/constants/app_constants.dart';

class SupabaseDatasource {
  final SupabaseClient _client;
  static const _uuid = Uuid();

  SupabaseDatasource(this._client);

  SupabaseClient get client => _client;
  String? get currentUserId => _client.auth.currentUser?.id;

  // ── AUTH ──

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> profileData,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: profileData,
    );
    return response;
  }

  /// Makes sure the current user has a profile row and that fields the
  /// handle_new_user trigger didn't set (phone, city, company_name) get
  /// filled in from auth user_metadata when available.
  Future<void> ensureProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final meta = user.userMetadata ?? <String, dynamic>{};

    final existing = await _client
        .from('profiles')
        .select('id, phone, city, company_name')
        .eq('id', user.id)
        .maybeSingle();

    if (existing == null) {
      // Trigger missed — heal by inserting ourselves.
      await _client.from('profiles').insert({
        'id': user.id,
        'full_name': (meta['full_name'] as String?) ?? 'Usuario',
        'role': (meta['role'] as String?) ?? 'trabajador',
        if (meta['phone'] != null) 'phone': meta['phone'],
        if (meta['city'] != null) 'city': meta['city'],
        if (meta['company_name'] != null) 'company_name': meta['company_name'],
      });
      return;
    }

    if (meta.isEmpty) return;

    final updates = <String, dynamic>{};
    if ((existing['phone'] == null || existing['phone'] == '') && meta['phone'] != null) {
      updates['phone'] = meta['phone'];
    }
    if ((existing['city'] == null || existing['city'] == '') && meta['city'] != null) {
      updates['city'] = meta['city'];
    }
    if ((existing['company_name'] == null || existing['company_name'] == '') && meta['company_name'] != null) {
      updates['company_name'] = meta['company_name'];
    }
    if (updates.isNotEmpty) {
      await _client.from('profiles').update(updates).eq('id', user.id);
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ── PROFILES ──

  Future<Map<String, dynamic>> getProfile(String userId) async {
    return await _client.from('profiles').select().eq('id', userId).single();
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', userId);
  }

  /// Soft-delete the account by marking the profile as inactive.
  /// A full hard-delete would require a privileged edge function.
  Future<void> deleteAccount(String userId) async {
    await _client.from('profiles').update({'is_active': false}).eq('id', userId);
  }

  // ── CATEGORIES ──

  Future<List<Map<String, dynamic>>> getCategories() async {
    return await _client
        .from('categories')
        .select('id, name, icon')
        .eq('is_active', true)
        .order('name');
  }

  Future<String?> resolveCategoryId(String nameOrSlug) async {
    final row = await _client
        .from('categories')
        .select('id')
        .ilike('name', '%$nameOrSlug%')
        .maybeSingle();
    return row?['id'] as String?;
  }

  // ── JOB POSTS ──

  Future<List<Map<String, dynamic>>> getJobPosts({
    int offset = 0,
    int limit = AppConstants.pageSize,
    String? categoryId,
    String? city,
    String? payType,
    double? minPay,
    double? maxPay,
    String? search,
  }) async {
    var query = _client
        .from('job_posts')
        .select('*, employer:profiles!employer_id(full_name, avatar_url, average_rating), category:categories(id, name, icon)')
        .eq('status', 'active');

    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (city != null) query = query.eq('city', city);
    if (payType != null) query = query.eq('pay_type', payType);
    if (minPay != null) query = query.gte('pay_amount', minPay);
    if (maxPay != null) query = query.lte('pay_amount', maxPay);
    if (search != null && search.isNotEmpty) {
      query = query.or('title.ilike.%$search%,description.ilike.%$search%');
    }

    return await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
  }

  Future<Map<String, dynamic>> getJobPost(String jobPostId) async {
    return await _client
        .from('job_posts')
        .select('*, employer:profiles!employer_id(full_name, avatar_url, average_rating), category:categories(id, name, icon)')
        .eq('id', jobPostId)
        .single();
  }

  Future<List<Map<String, dynamic>>> getEmployerJobPosts(String employerId, {String? status}) async {
    var query = _client
        .from('job_posts')
        .select('*, employer:profiles!employer_id(full_name, avatar_url, average_rating), category:categories(id, name, icon)')
        .eq('employer_id', employerId);
    if (status != null) query = query.eq('status', status);
    return await query.order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> createJobPost(Map<String, dynamic> data) async {
    return await _client.from('job_posts').insert(data).select().single();
  }

  Future<void> updateJobPost(String id, Map<String, dynamic> data) async {
    await _client.from('job_posts').update(data).eq('id', id);
  }

  // ── JOB APPLICATIONS ──

  Future<Map<String, dynamic>> createApplication(Map<String, dynamic> data) async {
    return await _client.from('job_applications').insert(data).select().single();
  }

  Future<List<Map<String, dynamic>>> getWorkerApplications(String workerId, {String? status}) async {
    var query = _client
        .from('job_applications')
        .select('*, worker:profiles!worker_id(full_name, avatar_url), job_post:job_posts(*, employer:profiles!employer_id(full_name, avatar_url), category:categories(id, name, icon)), application_attachments(file_url)')
        .eq('worker_id', workerId);
    if (status != null) query = query.eq('status', status);
    return await query.order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getJobApplications(String jobPostId) async {
    return await _client
        .from('job_applications')
        .select('*, worker:profiles!worker_id(full_name, avatar_url, average_rating, total_ratings, completed_jobs), application_attachments(file_url)')
        .eq('job_post_id', jobPostId)
        .order('created_at', ascending: false);
  }

  Future<void> updateApplicationStatus(String applicationId, String status) async {
    await _client.from('job_applications').update({'status': status}).eq('id', applicationId);
  }

  Future<bool> hasApplied(String jobPostId, String workerId) async {
    final response = await _client
        .from('job_applications')
        .select('id')
        .eq('job_post_id', jobPostId)
        .eq('worker_id', workerId)
        .maybeSingle();
    return response != null;
  }

  Future<Map<String, dynamic>?> getApplication(String jobPostId, String workerId) async {
    return await _client
        .from('job_applications')
        .select('*, application_attachments(file_url)')
        .eq('job_post_id', jobPostId)
        .eq('worker_id', workerId)
        .maybeSingle();
  }

  // ── APPLICATION ATTACHMENTS ──

  Future<void> createAttachment(String applicationId, String fileUrl) async {
    await _client.from('application_attachments').insert({
      'application_id': applicationId,
      'file_url': fileUrl,
    });
  }

  // ── ESCROW TRANSACTIONS ──

  Future<Map<String, dynamic>> createEscrowTransaction(Map<String, dynamic> data) async {
    return await _client.from('escrow_transactions').insert(data).select().single();
  }

  Future<Map<String, dynamic>?> getEscrowByJobPost(String jobPostId) async {
    return await _client
        .from('escrow_transactions')
        .select()
        .eq('job_post_id', jobPostId)
        .maybeSingle();
  }

  RealtimeChannel subscribeToEscrow(String jobPostId, void Function(Map<String, dynamic>) onUpdate) {
    return _client
        .channel('escrow_$jobPostId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'escrow_transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'job_post_id',
            value: jobPostId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  // ── WORK COMPLETIONS ──

  Future<Map<String, dynamic>> createWorkCompletion(Map<String, dynamic> data) async {
    return await _client.from('work_completions').insert(data).select().single();
  }

  Future<List<Map<String, dynamic>>> getWorkCompletions(String jobPostId) async {
    return await _client
        .from('work_completions')
        .select('*, worker:profiles!worker_id(full_name, avatar_url), job_post:job_posts(title)')
        .eq('job_post_id', jobPostId)
        .order('worker_marked_at', ascending: false);
  }

  Future<Map<String, dynamic>?> getWorkerCompletion(String jobPostId, String workerId) async {
    return await _client
        .from('work_completions')
        .select()
        .eq('job_post_id', jobPostId)
        .eq('worker_id', workerId)
        .maybeSingle();
  }

  Future<void> confirmWorkCompletion(String completionId) async {
    await _client.from('work_completions').update({
      'status': 'confirmed',
      'employer_confirmed_at': DateTime.now().toIso8601String(),
    }).eq('id', completionId);
  }

  // ── CONVERSATIONS ──

  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    final response = await _client
        .from('conversations')
        .select('*, employer:profiles!employer_id(full_name, avatar_url), worker:profiles!worker_id(full_name, avatar_url)')
        .or('employer_id.eq.$userId,worker_id.eq.$userId')
        .order('last_message_at', ascending: false);
    return response;
  }

  /// Get or create a conversation between an employer and a worker,
  /// optionally scoped to a specific job post.
  Future<Map<String, dynamic>> getOrCreateConversation({
    required String employerId,
    required String workerId,
    String? jobPostId,
  }) async {
    var query = _client
        .from('conversations')
        .select()
        .eq('employer_id', employerId)
        .eq('worker_id', workerId);
    if (jobPostId != null) {
      query = query.eq('job_post_id', jobPostId);
    }
    final existing = await query.maybeSingle();
    if (existing != null) return existing;

    return await _client.from('conversations').insert({
      'employer_id': employerId,
      'worker_id': workerId,
      'job_post_id': jobPostId,
    }).select().single();
  }

  // ── MESSAGES ──

  Future<List<Map<String, dynamic>>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    return await _client
        .from('messages')
        .select('*, profiles!sender_id(full_name, avatar_url)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
  }

  Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> data) async {
    final response = await _client.from('messages').insert(data).select().single();
    await _client.from('conversations').update({
      'last_message': data['content'],
      'last_message_at': DateTime.now().toIso8601String(),
    }).eq('id', data['conversation_id']);
    return response;
  }

  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  RealtimeChannel subscribeToMessages(String conversationId, void Function(Map<String, dynamic>) onMessage) {
    return _client
        .channel('messages_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) => onMessage(payload.newRecord),
        )
        .subscribe();
  }

  // ── RATINGS ──

  Future<void> createRating(Map<String, dynamic> data) async {
    await _client.from('ratings').insert(data);
  }

  Future<List<Map<String, dynamic>>> getRatingsForUser(String userId) async {
    return await _client
        .from('ratings')
        .select('*, rater:profiles!rater_id(full_name, avatar_url)')
        .eq('rated_id', userId)
        .order('created_at', ascending: false);
  }

  Future<bool> hasRated(String jobPostId, String raterId, String ratedId) async {
    final result = await _client
        .from('ratings')
        .select('id')
        .eq('job_post_id', jobPostId)
        .eq('rater_id', raterId)
        .eq('rated_id', ratedId)
        .maybeSingle();
    return result != null;
  }

  // ── DISPUTES ──

  Future<void> createDispute(Map<String, dynamic> data) async {
    await _client.from('disputes').insert(data);
  }

  Future<Map<String, dynamic>?> getDisputeForJob(String jobPostId, String reporterId) async {
    return await _client
        .from('disputes')
        .select()
        .eq('job_post_id', jobPostId)
        .eq('reported_by', reporterId)
        .maybeSingle();
  }

  // ── NOTIFICATIONS ──

  Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    return await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return response.length;
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  RealtimeChannel subscribeToNotifications(String userId, void Function(Map<String, dynamic>) onNotification) {
    return _client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onNotification(payload.newRecord),
        )
        .subscribe();
  }

  // ── STORAGE ──

  Future<String> uploadFile(String bucket, String filePath, File file) async {
    final ext = filePath.split('.').last;
    final fileName = '${_uuid.v4()}.$ext';
    final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';

    await _client.storage.from(bucket).upload(
      fileName,
      file,
      fileOptions: FileOptions(contentType: mimeType),
    );

    return _client.storage.from(bucket).getPublicUrl(fileName);
  }

  // ── EMPLOYER STATS ──

  Future<Map<String, int>> getEmployerStats(String employerId) async {
    final activeOffers = await _client
        .from('job_posts')
        .select('id')
        .eq('employer_id', employerId)
        .inFilter('status', ['active', 'in_progress']);

    final totalApplicants = await _client
        .from('job_applications')
        .select('id, job_posts!inner(employer_id)')
        .eq('job_posts.employer_id', employerId);

    final inProgress = await _client
        .from('job_posts')
        .select('id')
        .eq('employer_id', employerId)
        .eq('status', 'in_progress');

    return {
      'active_offers': activeOffers.length,
      'total_applicants': totalApplicants.length,
      'in_progress': inProgress.length,
    };
  }

  Future<List<Map<String, dynamic>>> getRecentApplicants(String employerId, {int limit = 5}) async {
    return await _client
        .from('job_applications')
        .select('*, profiles!worker_id(full_name, avatar_url), job_posts!inner(title, employer_id)')
        .eq('job_posts.employer_id', employerId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  // ── AI PROPOSALS ──

  Future<void> saveAiProposal(Map<String, dynamic> data) async {
    await _client.from('ai_proposals').insert(data);
  }
}
