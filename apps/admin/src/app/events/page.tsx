"use client";

import { useEffect, useState } from "react";
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
import { Button } from "@/components/ui/button";
import { RefreshCw } from "lucide-react";
import type { GameEvent } from "@/lib/types";
import { getEvents, getPlayers } from "@/lib/api";

function formatTimestamp(microseconds: number): string {
  const date = new Date(microseconds / 1000);
  return date.toLocaleString();
}

function getEventBadgeVariant(
  eventType: string
): "default" | "secondary" | "destructive" | "outline" {
  switch (eventType) {
    case "fish_caught":
      return "default";
    case "item_sold":
    case "item_bought":
      return "secondary";
    case "session_started":
    case "session_ended":
      return "outline";
    default:
      return "default";
  }
}

export default function EventsPage() {
  const [events, setEvents] = useState<GameEvent[]>([]);
  const [players, setPlayers] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
    try {
      const [eventsData, playersData] = await Promise.all([
        getEvents(100),
        getPlayers(),
      ]);
      setEvents(eventsData);
      setPlayers(playersData);
    } catch (error) {
      console.error("Failed to load events:", error);
    }
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, []);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Events</h1>
        <Button variant="outline" onClick={load} disabled={loading}>
          <RefreshCw className={`mr-2 h-4 w-4 ${loading ? "animate-spin" : ""}`} />
          Refresh
        </Button>
      </div>
      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Time</TableHead>
                <TableHead>Player</TableHead>
                <TableHead>Event</TableHead>
                <TableHead>Item</TableHead>
                <TableHead>Qty</TableHead>
                <TableHead>Gold</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-8">
                    Loading...
                  </TableCell>
                </TableRow>
              ) : events.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-8">
                    No events found
                  </TableCell>
                </TableRow>
              ) : (
                events.map((event) => (
                  <TableRow key={event.id}>
                    <TableCell className="text-sm">
                      {formatTimestamp(event.createdAt)}
                    </TableCell>
                    <TableCell>{players[event.playerId] || event.playerId}</TableCell>
                    <TableCell>
                      <Badge variant={getEventBadgeVariant(event.eventType)}>
                        {event.eventType}
                      </Badge>
                    </TableCell>
                    <TableCell className="font-mono text-sm">
                      {event.itemId || "-"}
                    </TableCell>
                    <TableCell>{event.quantity ?? "-"}</TableCell>
                    <TableCell>{event.goldAmount ?? "-"}</TableCell>
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
