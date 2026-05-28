// ════════════════════════════════════════════════════════
// TETRAPLASTIC - CONEXIÓN SUPABASE
// ════════════════════════════════════════════════════════

const SUPA_URL = 'https://rohdxjuuvpgrhevfsrye.supabase.co';
const SUPA_KEY = 'sb_publishable_PayfE36QRzwOnP6zA2TDSQ_oj4vnB5i';
const db = supabase.createClient(SUPA_URL, SUPA_KEY);

console.log('✅ Supabase conectado');
