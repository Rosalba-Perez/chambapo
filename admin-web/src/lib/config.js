const rt = (typeof window !== "undefined" && window.__CHAMBAPO__) || {};
export const SUPABASE_URL = rt.SUPABASE_URL || import.meta.env.VITE_SUPABASE_URL;
export const SUPABASE_ANON_KEY = rt.SUPABASE_ANON_KEY || import.meta.env.VITE_SUPABASE_ANON_KEY;
export const API_URL = rt.API_URL || import.meta.env.VITE_API_URL;
