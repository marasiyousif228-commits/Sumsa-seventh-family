export type Role = "president" | "secretary_general" | "finance_secretary" | "secretary" | "member";
export type TaskStatus = "not_started" | "in_progress" | "completed";
export type Priority = "low" | "medium" | "high" | "urgent";
export type Member = {
  id: string; full_name: string; email: string; phone: string | null;
  role: Role; position: string | null; secretariat_id: string | null;
  sub_office_id: string | null; avatar_url: string | null; membership_status: string;
};
export type Task = {
  id: string; title: string; description: string | null; secretariat_id: string;
  sub_office_id: string | null; assignee_id: string; created_by: string;
  assigned_at: string; due_at: string; priority: Priority; status: TaskStatus;
  notes: string | null; completed_at: string | null;
};
export const statusLabel: Record<TaskStatus,string> = {
  not_started:"لم تبدأ", in_progress:"قيد التنفيذ", completed:"مكتملة"
};
export const priorityLabel: Record<Priority,string> = {
  low:"منخفضة", medium:"متوسطة", high:"عالية", urgent:"عاجلة"
};
