class AppConstants {
  AppConstants._();

  // Supabase - passed via --dart-define
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // n8n
  static const String n8nBaseUrl = String.fromEnvironment(
    'N8N_BASE_URL',
    defaultValue: 'https://celuloko-n8n.kmy1zc.easypanel.host',
  );
  static const String n8nJobProposalWebhook = String.fromEnvironment(
    'N8N_JOB_PROPOSAL_WEBHOOK',
    defaultValue: '/webhook/fe6cf5c1-7313-463a-a3d9-9e9b54ff4b84',
  );

  // Bold
  static const String boldPaymentUrl = String.fromEnvironment('BOLD_PAYMENT_URL');

  // Storage buckets
  static const String avatarsBucket = 'avatars';
  static const String applicationAttachmentsBucket = 'application-attachments';
  static const String workEvidenceBucket = 'work-evidence';
  static const String audioProposalsBucket = 'audio-proposals';

  // Pagination
  static const int pageSize = 20;

  // Payment
  static const int paymentTimeoutMinutes = 10;
  static const int paymentPollingSeconds = 15;

  // Audio
  static const int maxAudioDurationSeconds = 120;

  // Attachments
  static const int maxApplicationImages = 5;
  static const int maxEvidenceImages = 3;

  // Colombian cities
  static const List<String> colombianCities = [
    'Bogotá',
    'Medellín',
    'Cali',
    'Barranquilla',
    'Cartagena',
    'Cúcuta',
    'Bucaramanga',
    'Pereira',
    'Santa Marta',
    'Ibagué',
    'Pasto',
    'Manizales',
    'Neiva',
    'Villavicencio',
    'Armenia',
    'Valledupar',
    'Montería',
    'Sincelejo',
    'Popayán',
    'Tunja',
    'Riohacha',
    'Quibdó',
    'Florencia',
    'Yopal',
    'Mocoa',
    'Leticia',
    'Inírida',
    'Puerto Carreño',
    'Mitú',
    'San José del Guaviare',
    'Arauca',
    'San Andrés',
  ];

  // Job categories
  static const Map<String, String> jobCategories = {
    'construccion': '🏗️ Construcción',
    'limpieza': '🧹 Limpieza',
    'jardineria': '🌿 Jardinería',
    'mudanzas': '📦 Mudanzas',
    'pintura': '🎨 Pintura',
    'plomeria': '🔧 Plomería',
    'electricidad': '⚡ Electricidad',
    'cocina': '👨‍🍳 Cocina',
    'mesero': '🍽️ Mesero/a',
    'cuidado_personas': '👶 Cuidado de personas',
    'conduccion': '🚗 Conducción',
    'reparaciones': '🔨 Reparaciones',
    'tecnologia': '💻 Tecnología',
    'diseno': '🎨 Diseño',
    'ensenanza': '📚 Enseñanza',
    'ventas': '🛒 Ventas',
    'eventos': '🎉 Eventos',
    'seguridad': '🛡️ Seguridad',
    'agricultura': '🌾 Agricultura',
    'otro': '📋 Otro',
  };

  // Pay types (must match DB check: hora/dia/semana/mes/por_trabajo)
  static const Map<String, String> payTypes = {
    'hora': 'Por hora',
    'dia': 'Por día',
    'semana': 'Por semana',
    'mes': 'Por mes',
    'por_trabajo': 'Por trabajo',
  };

  // Dispute reasons
  static const List<String> disputeReasons = [
    'Trabajo no completado',
    'Calidad insatisfactoria',
    'No se presentó',
    'Pago no recibido',
    'Condiciones diferentes a las acordadas',
    'Comportamiento inapropiado',
    'Otro',
  ];
}
