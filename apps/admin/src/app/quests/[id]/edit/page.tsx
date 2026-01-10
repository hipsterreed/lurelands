"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
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
import { getQuests, updateQuest } from "@/lib/api";
import type { Quest } from "@/lib/types";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";

export default function EditQuestPage() {
  const params = useParams();
  const router = useRouter();
  const questId = params.id as string;

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [existingQuests, setExistingQuests] = useState<Quest[]>([]);
  const [storylines, setStorylines] = useState<string[]>([]);
  const [customStoryline, setCustomStoryline] = useState("");

  const [formData, setFormData] = useState({
    id: "",
    title: "",
    description: "",
    questType: "story" as "story" | "daily",
    storyline: "",
    storyOrder: "",
    prerequisiteQuestId: "",
    requirements: "[]",
    rewards: "[]",
  });

  useEffect(() => {
    async function load() {
      try {
        const quests = await getQuests();
        setExistingQuests(quests);

        // Extract unique storylines
        const uniqueStorylines = new Set<string>();
        for (const q of quests) {
          if (q.storyline) {
            uniqueStorylines.add(q.storyline);
          }
        }
        setStorylines(Array.from(uniqueStorylines).sort());

        const quest = quests.find((q) => q.id === questId);
        if (quest) {
          setFormData({
            id: quest.id,
            title: quest.title,
            description: quest.description,
            questType: quest.questType,
            storyline: quest.storyline || "",
            storyOrder: quest.storyOrder?.toString() || "",
            prerequisiteQuestId: quest.prerequisiteQuestId || "",
            requirements: quest.requirements,
            rewards: quest.rewards,
          });
        }
      } catch (error) {
        console.error("Failed to load quest:", error);
      }
      setLoading(false);
    }
    load();
  }, [questId]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);

    const finalStoryline = formData.storyline === "__custom__"
      ? customStoryline
      : formData.storyline;

    try {
      await updateQuest(questId, {
        title: formData.title,
        description: formData.description,
        questType: formData.questType,
        storyline: finalStoryline || null,
        storyOrder: formData.storyOrder ? parseInt(formData.storyOrder) : null,
        prerequisiteQuestId: formData.prerequisiteQuestId || null,
        requirements: formData.requirements,
        rewards: formData.rewards,
      });
      router.push("/quests");
    } catch (error) {
      console.error("Failed to update quest:", error);
      alert("Failed to update quest");
    }
    setSaving(false);
  }

  // Filter quests for prerequisite dropdown (exclude current quest, only story quests)
  const storyQuests = existingQuests.filter(q => q.questType === "story" && q.id !== questId);

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/quests">
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <h1 className="text-2xl font-semibold">Edit Quest</h1>
        </div>
        <Card>
          <CardContent className="py-8 text-center">Loading...</CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/quests">
            <ArrowLeft className="h-4 w-4" />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold">Edit Quest</h1>
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
              <p className="text-xs text-muted-foreground">ID: {formData.id}</p>
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
                  value={formData.storyline || "__none__"}
                  onValueChange={(v) => setFormData({ ...formData, storyline: v === "__none__" ? "" : v })}
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
                  value={formData.prerequisiteQuestId || "__none__"}
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
                {saving ? "Saving..." : "Save Changes"}
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
