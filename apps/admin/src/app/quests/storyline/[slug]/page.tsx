"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type { Quest } from "@/lib/types";
import { getQuests, deleteQuest } from "@/lib/api";
import { ArrowLeft, Pencil, Trash2, Plus } from "lucide-react";
import Link from "next/link";

export default function StorylinePage() {
  const params = useParams();
  const slug = decodeURIComponent(params.slug as string);
  const isDaily = slug === "daily";

  const [quests, setQuests] = useState<Quest[]>([]);
  const [loading, setLoading] = useState(true);

  async function loadQuests() {
    setLoading(true);
    try {
      const data = await getQuests();
      const filtered = data.filter((q) => {
        if (isDaily) {
          return q.questType === "daily";
        }
        return q.questType === "story" && (q.storyline || "Uncategorized") === slug;
      });
      // Sort by storyOrder
      filtered.sort((a, b) => (a.storyOrder ?? 0) - (b.storyOrder ?? 0));
      setQuests(filtered);
    } catch (error) {
      console.error("Failed to load quests:", error);
    }
    setLoading(false);
  }

  useEffect(() => {
    loadQuests();
  }, [slug]);

  async function handleDelete(id: string) {
    if (!confirm("Are you sure you want to delete this quest?")) return;
    try {
      await deleteQuest(id);
      loadQuests();
    } catch (error) {
      console.error("Failed to delete quest:", error);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/quests">
            <ArrowLeft className="h-4 w-4" />
          </Link>
        </Button>
        <div className="flex-1">
          <h1 className="text-2xl font-semibold">
            {isDaily ? "Daily Quests" : slug}
          </h1>
          <p className="text-sm text-muted-foreground">
            {quests.length} quest{quests.length !== 1 ? "s" : ""}
          </p>
        </div>
        <Button asChild>
          <Link href={`/quests/new?storyline=${encodeURIComponent(slug)}`}>
            <Plus className="mr-2 h-4 w-4" />
            Add Quest
          </Link>
        </Button>
      </div>

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-[60px]">Order</TableHead>
                <TableHead>ID</TableHead>
                <TableHead>Title</TableHead>
                <TableHead>Description</TableHead>
                <TableHead>Prerequisite</TableHead>
                <TableHead className="w-[100px]">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-8">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : quests.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-8">
                    No quests in this storyline
                  </TableCell>
                </TableRow>
              ) : (
                quests.map((quest, index) => (
                  <TableRow key={quest.id}>
                    <TableCell>
                      <Badge variant="outline">{quest.storyOrder ?? index + 1}</Badge>
                    </TableCell>
                    <TableCell className="font-mono text-sm">{quest.id}</TableCell>
                    <TableCell className="font-medium">{quest.title}</TableCell>
                    <TableCell className="max-w-[300px] truncate text-sm text-muted-foreground">
                      {quest.description}
                    </TableCell>
                    <TableCell className="font-mono text-sm">
                      {quest.prerequisiteQuestId || "-"}
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        <Button size="icon" variant="ghost" asChild>
                          <Link href={`/quests/${quest.id}/edit`}>
                            <Pencil className="h-4 w-4" />
                          </Link>
                        </Button>
                        <Button
                          size="icon"
                          variant="ghost"
                          onClick={() => handleDelete(quest.id)}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
