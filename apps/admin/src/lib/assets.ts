// Asset path utilities for item sprites

export function getItemSpritePath(spriteId: string): string {
  if (spriteId.startsWith("fish_")) {
    return `/assets/fish/${spriteId}.png`;
  }
  if (spriteId.startsWith("pole_")) {
    return `/assets/items/fishing_pole_${spriteId.split("_").pop()}.png`;
  }
  if (spriteId.startsWith("lure_")) {
    return `/assets/items/${spriteId}.png`;
  }
  return `/assets/items/${spriteId}.png`;
}

export function getWaterTypeColor(waterType: string | null): string {
  switch (waterType) {
    case "pond":
      return "bg-green-100 text-green-800";
    case "river":
      return "bg-blue-100 text-blue-800";
    case "ocean":
      return "bg-cyan-100 text-cyan-800";
    case "night":
      return "bg-purple-100 text-purple-800";
    default:
      return "bg-gray-100 text-gray-800";
  }
}

export function getCategoryColor(category: string): string {
  switch (category) {
    case "fish":
      return "bg-orange-100 text-orange-800";
    case "pole":
      return "bg-amber-100 text-amber-800";
    case "lure":
      return "bg-lime-100 text-lime-800";
    default:
      return "bg-gray-100 text-gray-800";
  }
}
