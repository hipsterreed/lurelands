"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { createQuest, getQuests } from "@/lib/api";
import type { Quest } from "@/lib/types";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";

function generateId(): string {
  return crypto.randomUUID();
}

export default function NewQuestPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const defaultStoryline = searchParams.get("storyline") || "";

  const [saving, setSaving] = useState(false);
  const [existingQuests, setExistingQuests] = useState<Quest[]>([]);
  const [storylines, setStorylines] = useState<string[]>([]);
  const [customStoryline, setCustomStoryline] = useState("");

  const [formData, setFormData] = useState({
    title: "",
    description: "",
    questType: defaultStoryline === "daily" ? "daily" : "story" as "story" | "daily",
    storyline: defaultStoryline === "daily" ? "" : defaultStoryline,
    storyOrder: "",
    prerequisiteQuestId: "",
    requirements: "[]",
    rewards: "[]",
    questGiverType: "" as "" | "npc" | "sign",
    questGiverId: "",
  });

  useEffect(() => {
    async function load() {
      try {
        const quests = await getQuests();
        setExistingQuests(quests);

        // Extract unique storylines
        const uniqueStorylines = new Set<string>();
        for (const quest of quests) {
          if (quest.storyline) {
            uniqueStorylines.add(quest.storyline);
          }
        }
        setStorylines(Array.from(uniqueStorylines).sort());
      } catch (error) {
        console.error("Failed to load quests:", error);
      }
    }
    load();
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);

    const finalStoryline = formData.storyline === "__custom__"
      ? customStoryline
      : formData.storyline;

    try {
      await createQuest({
        id: generateId(),
        title: formData.title,
        description: formData.description,
        questType: formData.questType,
        storyline: finalStoryline || null,
        storyOrder: formData.storyOrder ? parseInt(formData.storyOrder) : null,
        prerequisiteQuestId: formData.prerequisiteQuestId || null,
        requirements: formData.requirements,
        rewards: formData.rewards,
        questGiverType: formData.questGiverType && formData.questGiverType !== "__any__" ? formData.questGiverType : null,
        questGiverId: formData.questGiverId || null,
      });
      router.push("/quests");
    } catch (error) {
      console.error("Failed to create quest:", error);
      alert("Failed to create quest");
    }
    setSaving(false);
  }

  // Filter quests for prerequisite dropdown (only story quests make sense as prerequisites)
  const storyQuests = existingQuests.filter(q => q.questType === "story");

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/quests">
            <ArrowLeft className="h-4 w-4" />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold">New Quest</h1>
      </div>

      <Card>
        <CardContent className="pt-6">
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <label className="text-sm font-medium">Title</label>
              <Input
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                placeholder="Quest Title"
                required
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-medium">Description</label>
              <Textarea
                value={formData.description}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                placeholder="Quest description..."
                required
              />
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <label className="text-sm font-medium">Type</label>
                <Select
                  value={formData.questType}
                  onValueChange={(v) => setFormData({ ...formData, questType: v as "story" | "daily" })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="story">Story</SelectItem>
                    <SelectItem value="daily">Daily</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <label className="text-sm font-medium">Story Order</label>
                <Input
                  type="number"
                  value={formData.storyOrder}
                  onChange={(e) => setFormData({ ...formData, storyOrder: e.target.value })}
                  placeholder="1, 2, 3..."
                />
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <label className="text-sm font-medium">Storyline</label>
                <Select
                  value={formData.storyline}
                  onValueChange={(v) => setFormData({ ...formData, storyline: v })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select storyline..." />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="__none__">None</SelectItem>
                    {storylines.map((s) => (
                      <SelectItem key={s} value={s}>{s}</SelectItem>
                    ))}
                    <SelectItem value="__custom__">+ New Storyline</SelectItem>
                  </SelectContent>
                </Select>
                {formData.storyline === "__custom__" && (
                  <Input
                    value={customStoryline}
                    onChange={(e) => setCustomStoryline(e.target.value)}
                    placeholder="Enter new storyline name..."
                    className="mt-2"
                  />
                )}
              </div>
              <div className="space-y-2">
                <label className="text-sm font-medium">Prerequisite Quest</label>
                <Select
                  value={formData.prerequisiteQuestId}
                  onValueChange={(v) => setFormData({ ...formData, prerequisiteQuestId: v === "__none__" ? "" : v })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select prerequisite..." />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="__none__">None</SelectItem>
                    {storyQuests.map((q) => (
                      <SelectItem key={q.id} value={q.id}>
                        {q.title} ({q.id})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <label className="text-sm font-medium">Quest Giver Type</label>
                <Select
                  value={formData.questGiverType}
                  onValueChange={(v) => setFormData({ ...formData, questGiverType: v as "" | "npc" | "sign" })}
                >
                  <SelectTrigger>
                    <SelectValue placeholder="Select giver type..." />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="__any__">Any Sign (storyline filter)</SelectItem>
                    <SelectItem value="sign">Specific Sign</SelectItem>
                    <SelectItem value="npc">NPC</SelectItem>
                  </SelectContent>
                </Select>
                <p className="text-xs text-muted-foreground">
                  Where players can pick up this quest
                </p>
              </div>
              <div className="space-y-2">
                <label className="text-sm font-medium">Quest Giver ID</label>
                <Input
                  value={formData.questGiverId}
                  onChange={(e) => setFormData({ ...formData, questGiverId: e.target.value })}
                  placeholder={formData.questGiverType === "npc" ? "e.g., guild_master" : "e.g., town_board"}
                  disabled={!formData.questGiverType || formData.questGiverType === "__any__"}
                />
                <p className="text-xs text-muted-foreground">
                  {formData.questGiverType === "npc" ? "The NPC ID that gives this quest" :
                   formData.questGiverType === "sign" ? "The Sign ID for this quest" :
                   "Leave empty for any sign with matching storyline"}
                </p>
              </div>
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <label className="text-sm font-medium">Requirements (JSON)</label>
                <Textarea
                  value={formData.requirements}
                  onChange={(e) => setFormData({ ...formData, requirements: e.target.value })}
                  placeholder='[{"type": "catch_fish", "count": 5}]'
                  className="font-mono text-sm"
                  rows={4}
                />
              </div>
              <div className="space-y-2">
                <label className="text-sm font-medium">Rewards (JSON)</label>
                <Textarea
                  value={formData.rewards}
                  onChange={(e) => setFormData({ ...formData, rewards: e.target.value })}
                  placeholder='[{"type": "gold", "amount": 100}]'
                  className="font-mono text-sm"
                  rows={4}
                />
              </div>
            </div>

            <div className="flex gap-2 pt-4">
              <Button type="submit" disabled={saving}>
                {saving ? "Creating..." : "Create Quest"}
              </Button>
              <Button type="button" variant="outline" asChild>
                <Link href="/quests">Cancel</Link>
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
