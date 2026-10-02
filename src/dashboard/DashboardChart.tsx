import { Bar, BarChart, CartesianGrid, Cell, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Card, CardHeader } from "../components/ui/Card";
import { useI18n } from "../i18n/I18nContext";
import { dashboardAED, dashboardChartRows, type DashboardGroup } from "./dashboardSummary";

const colors = ["#2563eb", "#0d9488", "#d97706", "#7c3aed", "#e11d48"];
export function DashboardChart({ title, subtitle, groups }: { title: string; subtitle: string; groups: DashboardGroup[] }) {
  const { t, dir } = useI18n(), rtl = dir === "rtl";
  const rows = dashboardChartRows(groups);
  return <Card className="min-w-0 overflow-hidden">
    <CardHeader title={title} subtitle={subtitle} />
    {rows.length === 0 ? <p className="p-6 text-sm text-slate-500">{t("executiveDashboard.noData")}</p> : <>
      <div className="px-3 pt-4" dir="ltr" style={{ height: Math.max(180, rows.length * 42 + 32) }} aria-hidden="true">
        <ResponsiveContainer width="100%" height="100%" minWidth={0}>
          <BarChart data={rows} layout="vertical" margin={{ top: 4, right: 8, bottom: 4, left: 8 }}>
            <CartesianGrid horizontal={false} stroke="#e2e8f0" />
            <XAxis type="number" hide domain={[0, 100]} reversed={rtl} />
            <YAxis type="category" dataKey="label" width={100} orientation={rtl ? "right" : "left"} axisLine={false} tickLine={false}
              tick={({ x, y, payload }) => <text x={x} y={y} dy={4} textAnchor="end" direction={dir} unicodeBidi="plaintext" fill="#64748b" fontSize={11}>{String(payload.value).length > 16 ? `${String(payload.value).slice(0, 15)}…` : payload.value}</text>} />
            <Tooltip cursor={{ fill: "#f8fafc" }} content={({ active, payload }) => active && payload?.[0] ? <div dir={dir} className="max-w-64 rounded-lg border border-slate-200 bg-white p-3 text-sm shadow-sm"><p><bdi>{payload[0].payload.label}</bdi></p><p><bdi dir="ltr">{dashboardAED(payload[0].payload.minor)}</bdi></p></div> : null} />
            <Bar dataKey="weight" radius={4} isAnimationActive={false}>
              {rows.map((row, i) => <Cell key={row.id} fill={colors[i % colors.length]} />)}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
      <dl className="divide-y divide-slate-100 px-5 pb-3 text-sm">
        {groups.map((row, i) => <div key={row.id} className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1 py-2"><dt className="min-w-0 break-words"><span aria-hidden="true" className="me-2 inline-block h-2 w-2 rounded-full" style={{ background: colors[i % colors.length] }} /><bdi>{row.label}</bdi></dt><dd><bdi dir="ltr" className="font-medium tabular-nums text-slate-900">{dashboardAED(row.minor)}</bdi></dd></div>)}
      </dl>
    </>}
  </Card>;
}
