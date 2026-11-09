"use client";

import { Bar, BarChart, CartesianGrid, XAxis, YAxis } from "recharts";
import { ChartContainer, ChartLegend, ChartLegendContent, ChartTooltip, ChartTooltipContent, type ChartConfig } from "@/components/ui/chart";
import type { ReportMonth } from "@/types/report.types";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

const config = {
  alerts: { label: "Alerts handled", color: "#1F3A5F" },
  students: { label: "Students supported", color: "#d97706" },
} satisfies ChartConfig;

export function MonthlyChart({ months }: { months: ReportMonth[] }) {
  const data = months.map((m) => ({
    month: MONTHS[m.month - 1],
    alerts: m.alerts_handled,
    students: m.students_supported,
  }));
  return (
    <ChartContainer config={config} className="h-72 w-full">
      <BarChart data={data}>
        <CartesianGrid vertical={false} />
        <XAxis dataKey="month" tickLine={false} axisLine={false} />
        <YAxis allowDecimals={false} tickLine={false} axisLine={false} width={32} />
        <ChartTooltip content={<ChartTooltipContent />} />
        <ChartLegend content={<ChartLegendContent />} />
        <Bar dataKey="alerts" fill="var(--color-alerts)" radius={3} />
        <Bar dataKey="students" fill="var(--color-students)" radius={3} />
      </BarChart>
    </ChartContainer>
  );
}
