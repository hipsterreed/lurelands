"use client";

import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getItem, updateItem } from "@/lib/api";
import type { ItemDefinition } from "@/lib/types";
import { ItemSprite } from "@/components/item-sprite";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";

const SPRITE_OPTIONS = {
  fish: [
    "fish_pond_1", "fish_pond_2", "fish_pond_3", "fish_pond_4",
    "fish_river_1", "fish_river_2", "fish_river_3", "fish_river_4",
    "fish_ocean_1", "fish_ocean_2", "fish_ocean_3", "fish_ocean_4",
    "fish_night_1", "fish_night_2", "fish_night_3", "fish_night_4",
  ],
  pole: ["pole_1", "pole_2", "pole_3", "pole_4"],
  lure: ["lure_1", "lure_2", "lure_3", "lure_4"],
};

export default function EditItemPage() {
  const router = useRouter();
  const params = useParams();
  const itemId = params.id as string;

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [formData, setFormData] = useState({
    id: "",
    name: "",
    category: "fish" as "fish" | "pole" | "lure",
    waterType: "" as "pond" | "river" | "ocean" | "night" | "",
    tier: "1",
    buyPrice: "0",
    sellPrice: "10",
    stackSize: "5",
    spriteId: "",
    description: "",
    isActive: true,
    rarityMultipliers: "",
    metadata: "",
  });

  useEffect(() => {
    async function load() {
      try {
        const item = await getItem(itemId);
        if (item) {
          setFormData({
            id: item.id,
            name: item.name,
            category: item.category,
            waterType: item.waterType || "",
            tier: String(item.tier),
            buyPrice: String(item.buyPrice),
            sellPrice: String(item.sellPrice),
            stackSize: String(item.stackSize),
            spriteId: item.spriteId,
            description: item.description || "",
            isActive: item.isActive,
            rarityMultipliers: item.rarityMultipliers || "",
            metadata: item.metadata || "",
          });
        }
      } catch (error) {
        console.error("Failed to load item:", error);
      }
      setLoading(false);
    }
    load();
  }, [itemId]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);

    try {
      await updateItem(itemId, {
        name: formData.name,
        category: formData.category,
        waterType: formData.waterType || null,
        tier: parseInt(formData.tier),
        buyPrice: parseInt(formData.buyPrice),
        sellPrice: parseInt(formData.sellPrice),
        stackSize: parseInt(formData.stackSize),
        spriteId: formData.spriteId,
        description: formData.description || null,
        isActive: formData.isActive,
        rarityMultipliers: formData.rarityMultipliers || null,
        metadata: formData.metadata || null,
      });
      router.push("/items");
    } catch (error) {
      console.error("Failed to update item:", error);
      alert("Failed to update item");
    }
    setSaving(false);
  }

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/items">
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <h1 className="text-2xl font-semibold">Edit Item</h1>
        </div>
        <Card>
          <CardContent className="py-8 text-center">Loading...</CardContent>
        </Card>
      </div>
    );
  }

  const currentSprites = SPRITE_OPTIONS[formData.category] || [];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/items">
            <ArrowLeft className="h-4 w-4" />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold">Edit Item</h1>
      </div>

      <Card>
        <CardContent className="pt-6">
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <label className="text-sm font-medium">ID</label>
                <Input
                  value={formData.id}
                  disabled
                  className="bg-muted"
                />
                <p className="text-xs text-muted-foreground">
                  Item ID cannot be changed
                </p>
              </div>
              <div className="space-y-2">
                <label className="text-sm font-medium">Name</label>
                <Input
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="e.g., Golden Trout"
                  required
                />
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-3">
              <div className="space-y-2">
                <label className="text-sm font-medium">Category</label>
                <Select
                  value={formData.category}
                  onValueChange={(v) => setFormData({
                    ...formData,
                    category: v as "fish" | "pole" | "lure",
                    waterType: v === "fish" ? formData.waterType : "",
                  })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="fish">Fish</SelectItem>
                    <SelectItem value="pole">Pole</SelectItem>
                    <SelectItem value="lure">Lure</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              {formData.category === "fish" && (
                <div className="space-y-2">
                  <label className="text-sm font-medium">Water Type</label>
                  <Select
                    value={formData.waterType}
                    onValueChange={(v) => setFormData({ ...formData, waterType: v as typeof formData.waterType })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select water type..." />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="pond">Pond</SelectItem>
                      <SelectItem value="river">River</SelectItem>
                      <SelectItem value="ocean">Ocean</SelectItem>
                      <SelectItem value="night">Night</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              )}

              <div className="space-y-2">
                <label className="text-sm font-medium">Tier</label>
                <Select
                  value={formData.tier}
                  onValueChange={(v) => setFormData({ ...formData, tier: v })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="1">Tier 1</SelectItem>
                    <SelectItem value="2">Tier 2</SelectItem>
                    <SelectItem value="3">Tier 3</SelectItem>
                    <SelectItem value="4">Tier 4</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Sprite</label>
              <div className="flex flex-wrap gap-2 p-3 border rounded-md">
                {currentSprites.map((sprite) => (
                  <button
                    key={sprite}
                    type="button"
                    onClick={() => setFormData({ ...formData, spriteId: sprite })}
                    className={`p-2 rounded border-2 transition-colors ${
                      formData.spriteId === sprite
                        ? "border-primary bg-primary/10"
                        : "border-transparent hover:bg-muted"
                    }`}
                  >
                    <ItemSprite spriteId={sprite} size={48} />
                  </button>
                ))}
              </div>
              <p className="text-xs text-muted-foreground">
                Selected: {formData.spriteId || "None"}
              </p>
            </div>

            <div className="grid gap-4 md:grid-cols-3">
              <div className="space-y-2">
                <label className="text-sm font-medium">Buy Price</label>
                <Input
                  type="number"
                  value={formData.buyPrice}
                  onChange={(e) => setFormData({ ...formData, buyPrice: e.target.value })}
                  placeholder="0"
                />
                <p className="text-xs text-muted-foreground">
                  0 = not purchasable
                </p>
              </div>
              <div className="space-y-2">
                <label className="text-sm font-medium">Sell Price</label>
                <Input
                  type="number"
                  value={formData.sellPrice}
                  onChange={(e) => setFormData({ ...formData, sellPrice: e.target.value })}
                  placeholder="10"
                  required
                />
              </div>
              <div className="space-y-2">
                <label className="text-sm font-medium">Stack Size</label>
                <Input
                  type="number"
                  value={formData.stackSize}
                  onChange={(e) => setFormData({ ...formData, stackSize: e.target.value })}
                  placeholder="5"
                  required
                />
              </div>
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Description</label>
              <Textarea
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                placeholder="Item description..."
                rows={2}
              />
            </div>

            {formData.category === "fish" && (
              <div className="space-y-2">
                <label className="text-sm font-medium">Rarity Multipliers (JSON)</label>
                <Input
                  value={formData.rarityMultipliers}
                  onChange={(e) => setFormData({ ...formData, rarityMultipliers: e.target.value })}
                  placeholder='{"2": 2.0, "3": 4.0}'
                  className="font-mono text-sm"
                />
                <p className="text-xs text-muted-foreground">
                  Price multipliers for 2-star and 3-star catches
                </p>
              </div>
            )}

            <div className="flex items-center space-x-2">
              <Checkbox
                id="isActive"
                checked={formData.isActive}
                onCheckedChange={(checked) => setFormData({ ...formData, isActive: checked === true })}
              />
              <label htmlFor="isActive" className="text-sm font-medium">
                Active
              </label>
            </div>

            <div className="flex gap-2 pt-4">
              <Button type="submit" disabled={saving}>
                {saving ? "Saving..." : "Save Changes"}
              </Button>
              <Button type="button" variant="outline" asChild>
                <Link href="/items">Cancel</Link>
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
