import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { getPlayers, getQuests, getEvents } from "@/lib/api";
import { Users, ScrollText, Activity, Coins } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  let playerCount = 0;
  let questCount = 0;
  let recentEventsCount = 0;

  try {
    const [players, quests, events] = await Promise.all([
      getPlayers(),
      getQuests(),
      getEvents(100),
    ]);
    playerCount = Object.keys(players).length;
    questCount = quests.length;
    recentEventsCount = events.length;
  } catch {
    // API not available
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Dashboard</h1>
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Players</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{playerCount}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Quests</CardTitle>
            <ScrollText className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{questCount}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Recent Events</CardTitle>
            <Activity className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{recentEventsCount}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">API Status</CardTitle>
            <Coins className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {playerCount > 0 || questCount > 0 ? "Connected" : "Offline"}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
