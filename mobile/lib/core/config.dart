// Datos de configuración de la app
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://xxxx.supabase.co');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'cambiar');
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://api.chambapo.co');
  static const osrmUrl = 'https://router.project-osrm.org';
}
