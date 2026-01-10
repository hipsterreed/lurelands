"use client";

import { getItemSpritePath } from "@/lib/assets";
import { useState } from "react";

interface ItemSpriteProps {
  spriteId: string;
  size?: number;
  className?: string;
}

export function ItemSprite({ spriteId, size = 32, className = "" }: ItemSpriteProps) {
  const [error, setError] = useState(false);

  if (error) {
    return (
      <div
        className={`bg-muted rounded flex items-center justify-center ${className}`}
        style={{ width: size, height: size }}
      >
        <span className="text-xs text-muted-foreground">?</span>
      </div>
    );
  }

  return (
    <img
      src={getItemSpritePath(spriteId)}
      alt={spriteId}
      width={size}
      height={size}
      className={className}
      style={{ imageRendering: "pixelated" }}
      onError={() => setError(true)}
    />
  );
}
