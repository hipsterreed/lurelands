import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { getPlayers, getQuests, getEvents, getDebugInfo } from "@/lib/api";
import { Users, ScrollText, Activity, Wifi, WifiOff } from "lucide-react";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  let playerCount = 0;
  let questCount = 0;
  let recentEventsCount = 0;
  let connected = false;
  let spacetimeConnected = false;
  let error: string | null = null;

  try {
    const [players, quests, events, debug] = await Promise.all([
      getPlayers(),
      getQuests(),
      getEvents(100),
      getDebugInfo(),
    ]);
    playerCount = Object.keys(players).length;
    questCount = quests.length;
    recentEventsCount = events.length;
    connected = true;
    spacetimeConnected = debug.connected;
  } catch (e) {
    error = e instanceof Error ? e.message : "Unknown error";
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Dashboard</h1>
        <div className="flex items-center gap-2">
          {connected ? (
            <Badge variant="outline" className="gap-1">
              <Wifi className="h-3 w-3" />
              Bridge: Connected
            </Badge>
          ) : (
            <Badge variant="destructive" className="gap-1">
              <WifiOff className="h-3 w-3" />
              Bridge: Offline
            </Badge>
          )}
          {connected && (
            <Badge variant={spacetimeConnected ? "outline" : "secondary"} className="gap-1">
              SpacetimeDB: {spacetimeConnected ? "Connected" : "Disconnected"}
            </Badge>
          )}
        </div>
      </div>

      {error && (
        <Card className="border-destructive">
          <CardContent className="pt-6">
            <p className="text-sm text-destructive">
              <strong>Connection Error:</strong> {error}
            </p>
            <p className="text-sm text-muted-foreground mt-2">
              Make sure the bridge is running: <code className="bg-muted px-1 rounded">cd services/bridge && bun run dev</code>
            </p>
          </CardContent>
        </Card>
      )}

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
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
      </div>
    </div>
  );
}
