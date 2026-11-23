#!/bin/sh
printenv | grep -E '^(DJANGO_|DATABASE_URL|SUPABASE_|FIREBASE_|NOMINATIM_)' | sed 's/^\(.*\)$/export \1/' > /etc/chambapo.env
chmod 600 /etc/chambapo.env
exec cron -f
