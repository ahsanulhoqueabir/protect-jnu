import Image from "next/image";
import { cn } from "@/lib/utils";

/** Protect JnU'ins logo. Square source, rendered uncropped at its natural aspect ratio. */
export function BrandLogo({
  size = 40,
  className,
  priority,
}: {
  size?: number;
  className?: string;
  priority?: boolean;
}) {
  return (
    <Image
      src="/brand/logo.png"
      alt="Protect JnU'ins logo"
      width={size}
      height={size}
      priority={priority}
      className={cn("object-contain", className)}
    />
  );
}
