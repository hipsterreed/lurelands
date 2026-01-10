"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import type { Quest } from "@/lib/types";
import {
  getQuests,
  createQuest,
  updateQuest,
  deleteQuest,
  seedQuests,
} from "@/lib/api";
import { Plus, Pencil, Trash2, RefreshCw } from "lucide-react";

export default function QuestsPage() {
  const [quests, setQuests] = useState<Quest[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingQuest, setEditingQuest] = useState<Quest | null>(null);
  const [isCreating, setIsCreating] = useState(false);

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

  async function loadQuests() {
    setLoading(true);
    try {
      const data = await getQuests();
      setQuests(data);
    } catch (error) {
      console.error("Failed to load quests:", error);
    }
    setLoading(false);
  }

  useEffect(() => {
    loadQuests();
  }, []);

  function resetForm() {
    setFormData({
      id: "",
      title: "",
      description: "",
      questType: "story",
      storyline: "",
      storyOrder: "",
      prerequisiteQuestId: "",
      requirements: "[]",
      rewards: "[]",
    });
    setEditingQuest(null);
    setIsCreating(false);
  }

  function handleEdit(quest: Quest) {
    setEditingQuest(quest);
    setIsCreating(false);
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

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const questData = {
      id: formData.id,
      title: formData.title,
      description: formData.description,
      questType: formData.questType,
      storyline: formData.storyline || null,
      storyOrder: formData.storyOrder ? parseInt(formData.storyOrder) : null,
      prerequisiteQuestId: formData.prerequisiteQuestId || null,
      requirements: formData.requirements,
      rewards: formData.rewards,
    };

    try {
      if (editingQuest) {
        await updateQuest(editingQuest.id, questData);
      } else {
        await createQuest(questData);
      }
      resetForm();
      loadQuests();
    } catch (error) {
      console.error("Failed to save quest:", error);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm("Are you sure you want to delete this quest?")) return;
    try {
      await deleteQuest(id);
      loadQuests();
    } catch (error) {
      console.error("Failed to delete quest:", error);
    }
  }

  async function handleSeed() {
    if (!confirm("This will seed default quests. Continue?")) return;
    try {
      await seedQuests();
      loadQuests();
    } catch (error) {
      console.error("Failed to seed quests:", error);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Quests</h1>
        <div className="flex gap-2">
          <Button variant="outline" onClick={handleSeed}>
            <RefreshCw className="mr-2 h-4 w-4" />
            Seed Defaults
          </Button>
          <Button
            onClick={() => {
              resetForm();
              setIsCreating(true);
            }}
          >
            <Plus className="mr-2 h-4 w-4" />
            New Quest
          </Button>
        </div>
      </div>

      {(isCreating || editingQuest) && (
        <Card>
          <CardHeader>
            <CardTitle>
              {editingQuest ? "Edit Quest" : "Create Quest"}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <label className="text-sm font-medium">ID</label>
                  <Input
                    value={formData.id}
                    onChange={(e) =>
                      setFormData({ ...formData, id: e.target.value })
                    }
                    placeholder="quest_id"
                    disabled={!!editingQuest}
                    required
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium">Title</label>
                  <Input
                    value={formData.title}
                    onChange={(e) =>
                      setFormData({ ...formData, title: e.target.value })
                    }
                    placeholder="Quest Title"
                    required
                  />
                </div>
              </div>
              <div className="space-y-2">
                <label className="text-sm font-medium">Description</label>
                <Textarea
                  value={formData.description}
                  onChange={(e) =>
                    setFormData({ ...formData, description: e.target.value })
                  }
                  placeholder="Quest description..."
                  required
                />
              </div>
              <div className="grid gap-4 md:grid-cols-4">
                <div className="space-y-2">
                  <label className="text-sm font-medium">Type</label>
                  <Select
                    value={formData.questType}
                    onValueChange={(v) =>
                      setFormData({
                        ...formData,
                        questType: v as "story" | "daily",
                      })
                    }
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
                  <label className="text-sm font-medium">Storyline</label>
                  <Input
                    value={formData.storyline}
                    onChange={(e) =>
                      setFormData({ ...formData, storyline: e.target.value })
                    }
                    placeholder="main, tutorial..."
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium">Story Order</label>
                  <Input
                    type="number"
                    value={formData.storyOrder}
                    onChange={(e) =>
                      setFormData({ ...formData, storyOrder: e.target.value })
                    }
                    placeholder="1, 2, 3..."
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium">Prerequisite</label>
                  <Input
                    value={formData.prerequisiteQuestId}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        prerequisiteQuestId: e.target.value,
                      })
                    }
                    placeholder="previous_quest_id"
                  />
                </div>
              </div>
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <label className="text-sm font-medium">Requirements (JSON)</label>
                  <Textarea
                    value={formData.requirements}
                    onChange={(e) =>
                      setFormData({ ...formData, requirements: e.target.value })
                    }
                    placeholder='[{"type": "catch_fish", "count": 5}]'
                    className="font-mono text-sm"
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-sm font-medium">Rewards (JSON)</label>
                  <Textarea
                    value={formData.rewards}
                    onChange={(e) =>
                      setFormData({ ...formData, rewards: e.target.value })
                    }
                    placeholder='[{"type": "gold", "amount": 100}]'
                    className="font-mono text-sm"
                  />
                </div>
              </div>
              <div className="flex gap-2">
                <Button type="submit">
                  {editingQuest ? "Update" : "Create"}
                </Button>
                <Button type="button" variant="outline" onClick={resetForm}>
                  Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>ID</TableHead>
                <TableHead>Title</TableHead>
                <TableHead>Type</TableHead>
                <TableHead>Storyline</TableHead>
                <TableHead className="w-[100px]">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-center py-8">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : quests.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="text-center py-8">
                    No quests found
                  </TableCell>
                </TableRow>
              ) : (
                quests.map((quest) => (
                  <TableRow key={quest.id}>
                    <TableCell className="font-mono text-sm">
                      {quest.id}
                    </TableCell>
                    <TableCell>{quest.title}</TableCell>
                    <TableCell>
                      <Badge
                        variant={
                          quest.questType === "story" ? "default" : "secondary"
                        }
                      >
                        {quest.questType}
                      </Badge>
                    </TableCell>
                    <TableCell>{quest.storyline || "-"}</TableCell>
                    <TableCell>
                      <div className="flex gap-1">
                        <Button
                          size="icon"
                          variant="ghost"
                          onClick={() => handleEdit(quest)}
                        >
                          <Pencil className="h-4 w-4" />
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
