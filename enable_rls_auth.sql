-- Fecha o acesso anónimo às tabelas da app.
-- Só o utilizador do Supabase Auth indicado em OWNER_UID tem acesso.
-- Aplicar só depois de a nova versão da app (com login) estar instalada.

-- Sem acesso para quem não tem sessão iniciada
revoke all on public.todo_cesar, public.todo_labels, public.todo_task_labels,
              public.todo_with_labels, public.todos, public.users
  from anon;

alter table public.todo_cesar       enable row level security;
alter table public.todo_labels      enable row level security;
alter table public.todo_task_labels enable row level security;
alter table public.todos            enable row level security;

-- A view passa a respeitar o RLS das tabelas por baixo (senão corre como owner)
alter view public.todo_with_labels set (security_invoker = true);

create policy "owner only" on public.todo_cesar
  for all to authenticated
  using ((select auth.uid()) = 'OWNER_UID') with check ((select auth.uid()) = 'OWNER_UID');

create policy "owner only" on public.todo_labels
  for all to authenticated
  using ((select auth.uid()) = 'OWNER_UID') with check ((select auth.uid()) = 'OWNER_UID');

create policy "owner only" on public.todo_task_labels
  for all to authenticated
  using ((select auth.uid()) = 'OWNER_UID') with check ((select auth.uid()) = 'OWNER_UID');

-- public.todos (vazia, não usada): RLS ligado sem policies = sem acesso pela API
