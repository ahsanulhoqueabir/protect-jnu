export const sb = {
  url: process.env.NEXT_PUBLIC_SUPABASE_URL!,
  secret: process.env.SUPABASE_SECRET_KEY!,
  publish: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
};

export const jt = {
  secret: process.env.JWT_SECRET_KEY,
  expire: process.env.JWT_EXPIRES_IN || "1d",
  refresh: process.env.JWT_REFRESH_EXPIRES_IN || "15d",
};
