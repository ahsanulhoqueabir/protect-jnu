"use client";

import "leaflet/dist/leaflet.css";
import { useEffect, useRef, useState } from "react";
import { createClient } from "@supabase/supabase-js";
import type * as Leaflet from "leaflet";
import { mergePoints } from "@/lib/map/merge-points";
import type { LocationPoint } from "@/types/alert.types";

const POLL_MS = 5000;
const SLOW_POLL_MS = 30000;
/** OpenStreetMap public tiles with attribution (D-067). */
const TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
const ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors';

function agoText(iso: string, now: number): string {
  const s = Math.max(0, Math.round((now - Date.parse(iso)) / 1000));
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  return m < 60 ? `${m} min ago` : `${Math.floor(m / 60)} h ago`;
}

/**
 * Live map for one alert: Leaflet (client only) + OSM tiles, marker at the latest point and a
 * 20-point trail. Initial points come from our admin API, then Realtime `locations` inserts
 * (RLS: admin reads all) are merged in; polling covers a dropped socket. If tiles fail to load the
 * coordinates are still shown as text.
 */
export function LiveMap({
  alertId,
  initial,
  open,
  accessToken,
  supabaseUrl,
  publishableKey,
}: {
  alertId: string;
  initial: LocationPoint[];
  /** Alert still active/acknowledged: subscribe and poll. */
  open: boolean;
  accessToken: string;
  supabaseUrl: string;
  publishableKey: string;
}) {
  const [points, setPoints] = useState(() => mergePoints([], initial));
  const [tilesFailed, setTilesFailed] = useState(false);
  const [live, setLive] = useState(false);
  const [now, setNow] = useState(() => Date.now());
  const el = useRef<HTMLDivElement>(null);
  const map = useRef<Leaflet.Map | null>(null);
  const layers = useRef<{ marker: Leaflet.CircleMarker; trail: Leaflet.Polyline } | null>(null);
  const L = useRef<typeof Leaflet | null>(null);
  const fitted = useRef(false);

  // Build the map once (Leaflet touches `window`, so it is imported on the client only).
  useEffect(() => {
    let cancelled = false;
    void import("leaflet").then((leaflet) => {
      if (cancelled || !el.current || map.current) return;
      L.current = leaflet;
      const m = leaflet.map(el.current).setView([23.7104, 90.4074], 15);
      let loaded = 0;
      const tiles = leaflet.tileLayer(TILE_URL, { maxZoom: 19, attribution: ATTRIBUTION });
      tiles.on("tileload", () => {
        loaded++;
        setTilesFailed(false);
      });
      tiles.on("tileerror", () => {
        if (loaded === 0) setTilesFailed(true);
      });
      tiles.addTo(m);
      layers.current = {
        trail: leaflet.polyline([], { color: "#1F3A5F", weight: 3 }).addTo(m),
        marker: leaflet
          .circleMarker([0, 0], { radius: 9, color: "#fff", weight: 2, fillColor: "#dc2626", fillOpacity: 1 })
          .addTo(m),
      };
      map.current = m;
      setPoints((p) => [...p]); // draw what we already have
    });
    return () => {
      cancelled = true;
      map.current?.remove();
      map.current = null;
      layers.current = null;
      fitted.current = false;
    };
  }, []);

  // Draw: marker at the newest point, trail through the kept ones.
  useEffect(() => {
    const m = map.current;
    const l = layers.current;
    if (!m || !l || points.length === 0) return;
    const latlngs = points.map((p) => [p.latitude, p.longitude] as [number, number]);
    const last = latlngs[latlngs.length - 1];
    l.trail.setLatLngs(latlngs);
    l.marker.setLatLng(last);
    if (!fitted.current) {
      m.setView(last, 17);
      fitted.current = true;
    } else if (!m.getBounds().contains(last)) {
      m.panTo(last);
    }
  }, [points]);

  // Realtime inserts + polling fallback.
  useEffect(() => {
    if (!open) return;
    let stop = false;
    async function load() {
      const res = await fetch(`/api/admin/alerts/${alertId}/locations`, { cache: "no-store" });
      if (!res.ok || stop) return;
      const rows = (await res.json()).data as LocationPoint[];
      setPoints((cur) => mergePoints(cur, rows));
    }
    const client = createClient(supabaseUrl, publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    client.realtime.setAuth(accessToken);
    const channel = client
      .channel(`alert-locations-${alertId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "locations", filter: `alert_id=eq.${alertId}` },
        (payload) => {
          const r = payload.new as LocationPoint;
          setPoints((cur) =>
            mergePoints(cur, [
              {
                id: r.id,
                latitude: r.latitude,
                longitude: r.longitude,
                accuracy: r.accuracy,
                recorded_at: r.recorded_at,
              },
            ]),
          );
        },
      )
      .subscribe((status) => {
        const up = status === "SUBSCRIBED";
        setLive(up);
        if (up) void load();
      });
    return () => {
      stop = true;
      void client.removeChannel(channel);
    };
  }, [open, alertId, accessToken, supabaseUrl, publishableKey]);

  useEffect(() => {
    if (!open) return;
    const t = setInterval(
      () => {
        void fetch(`/api/admin/alerts/${alertId}/locations`, { cache: "no-store" })
          .then((r) => (r.ok ? r.json() : null))
          .then((j) => j && setPoints((cur) => mergePoints(cur, j.data as LocationPoint[])));
      },
      live ? SLOW_POLL_MS : POLL_MS,
    );
    return () => clearInterval(t);
  }, [open, live, alertId]);

  // "updated Xs ago" ticker.
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);

  const last = points[points.length - 1];
  return (
    <div>
      <div className="relative h-80 w-full overflow-hidden rounded border bg-zinc-100">
        <div ref={el} className="h-full w-full" />
        {tilesFailed && (
          <div className="absolute inset-x-0 top-0 z-[1000] bg-amber-100 px-3 py-2 text-sm text-amber-900">
            Map tiles unavailable. Coordinates are shown below.
          </div>
        )}
        {!last && (
          <div className="absolute inset-0 z-[1000] flex items-center justify-center bg-white/70 text-sm text-zinc-600">
            No location received yet.
          </div>
        )}
      </div>
      <p className="mt-2 text-sm text-zinc-600">
        {last ? (
          <>
            {last.latitude.toFixed(5)}, {last.longitude.toFixed(5)} · updated{" "}
            {agoText(last.recorded_at, now)}
            {open ? (live ? " · ● live" : " · ○ reconnecting") : " · alert closed"}
          </>
        ) : open ? (
          "Waiting for the student's phone."
        ) : (
          "No location was shared for this alert."
        )}
      </p>
    </div>
  );
}
