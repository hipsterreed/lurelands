"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type { ItemDefinition } from "@/lib/types";
import { getItems, seedItems, deleteItem } from "@/lib/api";
import { getWaterTypeColor } from "@/lib/assets";
import { ItemSprite } from "@/components/item-sprite";
import { RefreshCw, Plus, Pencil, Trash2 } from "lucide-react";
import Link from "next/link";

export default function ItemsPage() {
  const [items, setItems] = useState<ItemDefinition[]>([]);
  const [loading, setLoading] = useState(true);

  async function loadItems() {
    setLoading(true);
    try {
      const data = await getItems();
      setItems(data);
    } catch (error) {
      console.error("Failed to load items:", error);
    }
    setLoading(false);
  }

  useEffect(() => {
    loadItems();
  }, []);

  async function handleSeed() {
    if (!confirm("This will seed all default items (24 fish, poles, and lures). Continue?")) return;
    try {
      await seedItems();
      loadItems();
    } catch (error) {
      console.error("Failed to seed items:", error);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm(`Delete item "${id}"?`)) return;
    try {
      await deleteItem(id);
      loadItems();
    } catch (error) {
      console.error("Failed to delete item:", error);
    }
  }

  const fishItems = items.filter((item) => item.category === "fish");
  const poleItems = items.filter((item) => item.category === "pole");
  const lureItems = items.filter((item) => item.category === "lure");

  function ItemTable({ items, showWaterType = false }: { items: ItemDefinition[]; showWaterType?: boolean }) {
    if (items.length === 0) {
      return (
        <Card>
          <CardContent className="py-8 text-center text-muted-foreground">
            No items found
          </CardContent>
        </Card>
      );
    }

    return (
      <Card>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead className="w-12"></TableHead>
              <TableHead>Name</TableHead>
              {showWaterType && <TableHead>Water</TableHead>}
              <TableHead>Tier</TableHead>
              <TableHead className="text-right">Buy</TableHead>
              <TableHead className="text-right">Sell</TableHead>
              <TableHead>Status</TableHead>
              <TableHead className="w-24">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {items.map((item) => (
              <TableRow key={item.id}>
                <TableCell>
                  <ItemSprite spriteId={item.spriteId} size={32} />
                </TableCell>
                <TableCell>
                  <div>
                    <p className="font-medium">{item.name}</p>
                    <p className="text-xs text-muted-foreground">{item.id}</p>
                  </div>
                </TableCell>
                {showWaterType && (
                  <TableCell>
                    {item.waterType && (
                      <Badge variant="outline" className={getWaterTypeColor(item.waterType)}>
                        {item.waterType}
                      </Badge>
                    )}
                  </TableCell>
                )}
                <TableCell>
                  <Badge variant="secondary">T{item.tier}</Badge>
                </TableCell>
                <TableCell className="text-right">
                  {item.buyPrice > 0 ? `${item.buyPrice}g` : "-"}
                </TableCell>
                <TableCell className="text-right">{item.sellPrice}g</TableCell>
                <TableCell>
                  <Badge variant={item.isActive ? "default" : "secondary"}>
                    {item.isActive ? "Active" : "Inactive"}
                  </Badge>
                </TableCell>
                <TableCell>
                  <div className="flex gap-1">
                    <Button variant="ghost" size="icon" asChild>
                      <Link href={`/items/${item.id}/edit`}>
                        <Pencil className="h-4 w-4" />
                      </Link>
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => handleDelete(item.id)}
                    >
                      <Trash2 className="h-4 w-4 text-destructive" />
                    </Button>
                  </div>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Items</h1>
        <div className="flex gap-2">
          <Button variant="outline" onClick={loadItems} disabled={loading}>
            <RefreshCw className={`mr-2 h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </Button>
          <Button variant="outline" onClick={handleSeed} disabled={loading}>
            Seed Defaults
          </Button>
          <Button asChild>
            <Link href="/items/new">
              <Plus className="mr-2 h-4 w-4" />
              New Item
            </Link>
          </Button>
        </div>
      </div>

      {loading ? (
        <Card>
          <CardContent className="py-8 text-center">Loading...</CardContent>
        </Card>
      ) : items.length === 0 ? (
        <Card>
          <CardContent className="py-8 text-center">
            <p className="text-muted-foreground">No items found</p>
            <Button onClick={handleSeed} className="mt-4">
              Seed Default Items
            </Button>
          </CardContent>
        </Card>
      ) : (
        <Tabs defaultValue="fish">
          <TabsList>
            <TabsTrigger value="fish">
              Fish
              <Badge variant="secondary" className="ml-2">
                {fishItems.length}
              </Badge>
            </TabsTrigger>
            <TabsTrigger value="poles">
              Poles
              <Badge variant="secondary" className="ml-2">
                {poleItems.length}
              </Badge>
            </TabsTrigger>
            <TabsTrigger value="lures">
              Lures
              <Badge variant="secondary" className="ml-2">
                {lureItems.length}
              </Badge>
            </TabsTrigger>
          </TabsList>

          <TabsContent value="fish" className="mt-4">
            <ItemTable items={fishItems} showWaterType />
          </TabsContent>

          <TabsContent value="poles" className="mt-4">
            <ItemTable items={poleItems} />
          </TabsContent>

          <TabsContent value="lures" className="mt-4">
            <ItemTable items={lureItems} />
          </TabsContent>
        </Tabs>
      )}
    </div>
  );
}
