create or replace function private.notify_reminder_received()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  edge_function_url text := 'https://kmeuuwqcngxhcfeevzsy.supabase.co/functions/v1/send_reminder_notification';
  service_role_key text;
  request_id bigint;
begin
  service_role_key := current_setting('supabase.service_role_key', true);

  begin
    select net.http_post(
      url := edge_function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || coalesce(service_role_key, '')
      ),
      body := jsonb_build_object(
        'to_user_id', new.to_user_id,
        'content', new.content,
        'plan_id', new.plan_id
      )
    ) into request_id;
  exception
    when others then
      raise warning 'reminder notification request failed: %', sqlerrm;
  end;

  return new;
end;
$$;
