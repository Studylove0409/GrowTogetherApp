-- 提醒插入后异步调用 Edge Function 发 FCM 推送
CREATE OR REPLACE FUNCTION private.notify_reminder_received()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  edge_function_url text := 'https://kmeuuwqcngxhcfeevzsy.supabase.co/functions/v1/send_reminder_notification';
  service_role_key text;
  request_id bigint;
BEGIN
  service_role_key := current_setting('supabase.service_role_key', true);

  SELECT net.http_post(
    url := edge_function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_role_key
    ),
    body := jsonb_build_object(
      'to_user_id', NEW.to_user_id,
      'content', NEW.content,
      'plan_id', NEW.plan_id
    )
  ) INTO request_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_reminder_inserted ON public.reminders;
CREATE TRIGGER on_reminder_inserted
  AFTER INSERT ON public.reminders
  FOR EACH ROW
  EXECUTE FUNCTION private.notify_reminder_received();
