create table if not exists public.shipments (
  id text primary key,
  status text not null,
  hub text,
  updated_at timestamptz default now()
);
alter table public.shipments enable row level security;
drop policy if exists "anyone can read shipments" on public.shipments;
create policy "anyone can read shipments" on public.shipments
  for select to anon using (true);
insert into public.shipments (id, status, hub) values
  ('BH-1001', 'in transit', 'Lille'),
  ('BH-1002', 'delivered', 'Arras'),
  ('BH-1003', 'at warehouse', 'WH1')
on conflict (id) do nothing;
