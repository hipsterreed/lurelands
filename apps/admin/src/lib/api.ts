"use server";

import type { Quest, GameEvent, ItemDefinition } from "./types";

const API_URL = process.env.API_URL || "http://localhost:8080";
const SERVICE_KEY = process.env.SERVICE_KEY || "";

async function fetchApi<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${API_URL}${endpoint}`;
  const headers: HeadersInit = {
    "Content-Type": "application/json",
    "X-Service-Key": SERVICE_KEY,
    ...options.headers,
  };

  const res = await fetch(url, {
    ...options,
    headers,
    cache: "no-store",
  });

  if (!res.ok) {
    throw new Error(`API error: ${res.status} ${res.statusText}`);
  }

  return res.json();
}

// Health
export async function getHealth() {
  return fetchApi<{ status: string }>("/health");
}

// Players
export async function getPlayers(): Promise<Record<string, string>> {
  return fetchApi<Record<string, string>>("/api/players");
}

// Events
export async function getEvents(limit = 50): Promise<GameEvent[]> {
  return fetchApi<GameEvent[]>(`/api/events?limit=${limit}`);
}

// Quests
export async function getQuests(): Promise<Quest[]> {
  return fetchApi<Quest[]>("/api/quests");
}

export async function createQuest(
  quest: Omit<Quest, "id"> & { id: string }
): Promise<{ success: boolean }> {
  return fetchApi<{ success: boolean }>("/api/quests", {
    method: "POST",
    body: JSON.stringify(quest),
  });
}

export async function updateQuest(
  id: string,
  quest: Partial<Quest>
): Promise<{ success: boolean }> {
  return fetchApi<{ success: boolean }>(`/api/quests/${id}`, {
    method: "PUT",
    body: JSON.stringify(quest),
  });
}

export async function deleteQuest(id: string): Promise<{ success: boolean }> {
  return fetchApi<{ success: boolean }>(`/api/quests/${id}`, {
    method: "DELETE",
  });
}

export async function resetQuestProgress(
  id: string
): Promise<{ success: boolean }> {
  return fetchApi<{ success: boolean }>(`/api/quests/${id}/reset-progress`, {
    method: "POST",
  });
}

export async function seedQuests(): Promise<{
  success: boolean;
  message: string;
}> {
  return fetchApi<{ success: boolean; message: string }>("/api/quests/seed", {
    method: "POST",
  });
}

// Debug
export async function getDebugInfo(): Promise<{
  connected: boolean;
  questCount: number;
  quests: Quest[];
}> {
  return fetchApi("/api/debug");
}

// Items
export async function getItems(): Promise<ItemDefinition[]> {
  return fetchApi<ItemDefinition[]>("/api/items");
}

export async function getItem(id: string): Promise<ItemDefinition | null> {
  const items = await getItems();
  return items.find((item) => item.id === id) || null;
}

export async function createItem(
  item: ItemDefinition
): Promise<{ success: boolean }> {
  return fetchApi<{ success: boolean }>("/api/items", {
    method: "POST",
    body: JSON.stringify(item),
  });
}

export async function updateItem(
  id: string,
  item: Partial<ItemDefinition>
): Promise<{ success: boolean }> {
  return fetchApi<{ success: boolean }>(`/api/items/${id}`, {
    method: "PUT",
    body: JSON.stringify(item),
  });
}

export async function deleteItem(id: string): Promise<{ success: boolean }> {
  return fetchApi<{ success: boolean }>(`/api/items/${id}`, {
    method: "DELETE",
  });
}

export async function seedItems(): Promise<{
  success: boolean;
  message: string;
}> {
  return fetchApi<{ success: boolean; message: string }>("/api/items/seed", {
    method: "POST",
  });
}
