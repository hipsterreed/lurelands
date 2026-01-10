"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import type { Quest } from "@/lib/types";
import { getQuests, seedQuests } from "@/lib/api";
import { RefreshCw, ChevronRight } from "lucide-react";
import Link from "next/link";

interface StorylineGroup {
  name: string;
  questCount: number;
}

export default function QuestsPage() {
  const [quests, setQuests] = useState<Quest[]>([]);
  const [loading, setLoading] = useState(true);

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

  async function handleSeed() {
    if (!confirm("This will seed default quests. Continue?")) return;
    try {
      await seedQuests();
      loadQuests();
    } catch (error) {
      console.error("Failed to seed quests:", error);
    }
  }

  // Group quests by storyline
  const storylineMap = new Map<string, number>();
  let dailyCount = 0;

  for (const quest of quests) {
    if (quest.questType === "daily") {
      dailyCount++;
    } else {
      const storyline = quest.storyline || "Uncategorized";
      storylineMap.set(storyline, (storylineMap.get(storyline) || 0) + 1);
    }
  }

  const storylines: StorylineGroup[] = Array.from(storylineMap.entries())
    .map(([name, questCount]) => ({ name, questCount }))
    .sort((a, b) => a.name.localeCompare(b.name));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Quests</h1>
        <div className="flex gap-2">
          <Button variant="outline" onClick={handleSeed} disabled={loading}>
            <RefreshCw className={`mr-2 h-4 w-4 ${loading ? "animate-spin" : ""}`} />
            Seed Defaults
          </Button>
          <Button asChild>
            <Link href="/quests/new">New Quest</Link>
          </Button>
        </div>
      </div>

      {loading ? (
        <Card>
          <CardContent className="py-8 text-center">Loading...</CardContent>
        </Card>
      ) : quests.length === 0 ? (
        <Card>
          <CardContent className="py-8 text-center">
            <p className="text-muted-foreground">No quests found</p>
            <Button onClick={handleSeed} className="mt-4">
              Seed Default Quests
            </Button>
          </CardContent>
        </Card>
      ) : (
        <Tabs defaultValue="storylines">
          <TabsList>
            <TabsTrigger value="storylines">
              Storylines
              <Badge variant="secondary" className="ml-2">
                {storylines.length}
              </Badge>
            </TabsTrigger>
            <TabsTrigger value="daily">
              Daily Quests
              <Badge variant="secondary" className="ml-2">
                {dailyCount}
              </Badge>
            </TabsTrigger>
          </TabsList>

          <TabsContent value="storylines" className="mt-4">
            <div className="grid gap-3">
              {storylines.length === 0 ? (
                <Card>
                  <CardContent className="py-8 text-center text-muted-foreground">
                    No storylines found
                  </CardContent>
                </Card>
              ) : (
                storylines.map((storyline) => (
                  <Link
                    key={storyline.name}
                    href={`/quests/storyline/${encodeURIComponent(storyline.name)}`}
                  >
                    <Card className="hover:bg-muted/50 transition-colors cursor-pointer">
                      <CardContent className="flex items-center justify-between py-4">
                        <div>
                          <p className="font-medium">{storyline.name}</p>
                          <p className="text-sm text-muted-foreground">
                            {storyline.questCount} quest{storyline.questCount !== 1 ? "s" : ""}
                          </p>
                        </div>
                        <ChevronRight className="h-5 w-5 text-muted-foreground" />
                      </CardContent>
                    </Card>
                  </Link>
                ))
              )}
            </div>
          </TabsContent>

          <TabsContent value="daily" className="mt-4">
            {dailyCount === 0 ? (
              <Card>
                <CardContent className="py-8 text-center text-muted-foreground">
                  No daily quests found
                </CardContent>
              </Card>
            ) : (
              <Link href="/quests/storyline/daily">
                <Card className="hover:bg-muted/50 transition-colors cursor-pointer">
                  <CardContent className="flex items-center justify-between py-4">
                    <div>
                      <p className="font-medium">All Daily Quests</p>
                      <p className="text-sm text-muted-foreground">
                        {dailyCount} quest{dailyCount !== 1 ? "s" : ""}
                      </p>
                    </div>
                    <ChevronRight className="h-5 w-5 text-muted-foreground" />
                  </CardContent>
                </Card>
              </Link>
            )}
          </TabsContent>
        </Tabs>
      )}
    </div>
  );
}
