import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default function ItemsPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Items</h1>
      <Card>
        <CardHeader>
          <CardTitle>Coming Soon</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground">
            Item management will be available in a future update.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
