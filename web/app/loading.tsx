import { BrandLogo } from "@/components/brand-logo";

export default function Loading() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-white dark:bg-zinc-950">
      <BrandLogo size={72} priority className="animate-pulse" />
    </div>
  );
}
