import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Protect JnU'ins Admin",
    short_name: "Protect JnU'ins",
    description: "Admin dashboard for the Protect JnU'ins student safety system",
    start_url: "/admin",
    display: "standalone",
    background_color: "#ffffff",
    theme_color: "#1F3A5F",
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icons/maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
