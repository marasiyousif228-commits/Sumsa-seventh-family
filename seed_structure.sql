-- Optional template for offices; these are structural labels, not member records.
insert into public.sub_offices(secretariat_id,name)
select s.id,x.name from public.secretariats s
cross join (values ('مكتب التخطيط'),('مكتب المتابعة')) as x(name)
where s.name in ('السكرتارية العامة','السكرتارية الإعلامية')
on conflict(secretariat_id,name) do nothing;
