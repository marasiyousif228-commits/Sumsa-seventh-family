// Deploy with: supabase functions deploy task-reminders
// Configure RESEND_API_KEY and APP_BASE_URL as Edge Function secrets.
// Schedule this function daily using Supabase Cron/pg_cron or an external scheduler.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = {"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type"};
Deno.serve(async (req) => {
 if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
 const url=Deno.env.get("SUPABASE_URL")!, key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 const resend=Deno.env.get("RESEND_API_KEY"), from=Deno.env.get("MAIL_FROM"), base=Deno.env.get("APP_BASE_URL")||"";
 if(!resend||!from) return new Response(JSON.stringify({error:"Email provider secrets are not configured"}),{status:500,headers:{...cors,"Content-Type":"application/json"}});
 const db=createClient(url,key); const today=new Date(); const horizon=new Date(today);horizon.setDate(today.getDate()+2);
 const {data:tasks,error}=await db.from("tasks").select("id,title,due_at,status,assignee_id,profiles!tasks_assignee_id_fkey(email,full_name),notification_settings!left(enabled,reminder_days,overdue_enabled)").neq("status","completed");
 if(error)return new Response(JSON.stringify({error:error.message}),{status:500,headers:{...cors,"Content-Type":"application/json"}});
 let sent=0;
 for(const t of tasks||[]){
   const due=new Date(t.due_at+"T23:59:59Z"); const days=Math.ceil((due.getTime()-today.getTime())/86400000);
   const setting=Array.isArray(t.notification_settings)?t.notification_settings[0]:t.notification_settings;
   if(setting?.enabled===false)continue;
   const kind=days<0?"overdue":days<=((setting?.reminder_days)??2)?"upcoming":null;
   if(!kind||(kind==="overdue"&&setting?.overdue_enabled===false))continue;
   const {data:existing}=await db.from("notification_log").select("id").eq("task_id",t.id).eq("user_id",t.assignee_id).eq("kind",kind).maybeSingle();
   if(existing)continue;
   const profile=Array.isArray(t.profiles)?t.profiles[0]:t.profiles;if(!profile?.email)continue;
   const subject=kind==="overdue"?"تنبيه: تجاوز موعد تسليم المهمة":"تذكير: اقترب موعد تسليم المهمة";
   const html=`<div dir="rtl" style="font-family:Arial"><h2>${subject}</h2><p>مرحباً ${profile.full_name||""}</p><p>المهمة: <b>${t.title}</b></p><p>موعد التسليم: ${t.due_at}</p><p><a href="${base}">فتح نظام أسرة الدفعة السابعة</a></p></div>`;
   const response=await fetch("https://api.resend.com/emails",{method:"POST",headers:{"Authorization":`Bearer ${resend}`,"Content-Type":"application/json"},body:JSON.stringify({from,to:profile.email,subject,html})});
   if(response.ok){await db.from("notification_log").insert({task_id:t.id,user_id:t.assignee_id,kind});sent++;}
 }
 return new Response(JSON.stringify({sent}),{headers:{...cors,"Content-Type":"application/json"}});
});
