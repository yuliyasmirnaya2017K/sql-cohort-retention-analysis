/* 1.Очищаємо текстове поле дати реєстрації користувачів:
 * прибираємо пробіли та час,
 * замінюємо роздільники (./) на -
 */
with normalized_date as(
select*, 
REGEXP_REPLACE(
split_part (TRIM(signup_datetime), ' ',1),
            '[./]', '-', 'g') as cleaned_date
from cohort_users_raw cur),
/*Перевіряємо формат дати та перетворюємо очищені дати реєстраціїї у timestamp*/
users_parsed as
(
select user_id,
       signup_datetime,
       promo_signup_flag,
case when length(split_part(cleaned_date, '-', 3)) = 4 then 
                to_date(cleaned_date, 'DD-MM-YYYY')::timestamp 
           when length(split_part(cleaned_date, '-', 3)) = 2 then 
                to_date(cleaned_date, 'DD-MM-YY')::timestamp 
            when length(split_part(cleaned_date, '-', 1)) = 4 then  
                to_date(cleaned_date, 'YYYY-MM-DD')::timestamp 
else null
end signup_timestamp
from normalized_date
),
/*2.Очищаємо текстове поле дати події (активність):
 * прибираємо пробіли та час,
 * замінюємо роздільники (./) на - */
normalized_event_date as(
select *,
REGEXP_REPLACE(
split_part (TRIM(event_datetime), ' ',1),
            '[./]', '-', 'g') as cleaned_event_date
from cohort_events_raw cer),
user_activity  as(
select user_id,
       event_type,
/*Перевіряємо формат дати та перетворюємо очищені дати подій у timestamp
 */
case when length(split_part(cleaned_event_date, '-', 3)) = 4 then 
                to_date(cleaned_event_date, 'DD-MM-YYYY')::timestamp 
           when length(split_part(cleaned_event_date, '-', 3)) = 2 then 
                to_date(cleaned_event_date, 'DD-MM-YY')::timestamp 
            when length(split_part(cleaned_event_date, '-', 1)) = 4 then  
                to_date(cleaned_event_date, 'YYYY-MM-DD')::timestamp 
else null
end events_timestamp
from normalized_event_date
),
/* 3.Об'єднуємо користувачів, формуємо місяць когорти ('YYYY-MM'), місяць активності і стаж користувача
 */
joined_date as(
select ua.user_id,
       ua.event_type,
       up.promo_signup_flag,
       to_char(up.signup_timestamp, 'YYYY-MM')as cohort_month,--місяць когорти 
       to_char(ua.events_timestamp, 'YYYY-MM') as activity_month, --місяць активності
    (extract( year from ua.events_timestamp)-extract(year from up.signup_timestamp))*12+
    (extract(month from ua.events_timestamp)-extract(month from up.signup_timestamp))as month_offset --стаж користувача
from user_activity ua
join users_parsed up on ua.user_id=up.user_id  
where up.signup_timestamp is not null
        and ua.events_timestamp is not null
        and ua.event_type is not null
        and ua.event_type<>'test_event'
)
select promo_signup_flag,
       cohort_month,
       month_offset,
       count(distinct user_id )as users_total --рахуємо кількість користувачів
from joined_date
/*Застосовуємо фільтрацію, щоб обмежити період спостереження (січунь-червень)*/
       where activity_month between '2025-01'and '2025-06'
group by promo_signup_flag,
         cohort_month,
         month_offset 
order by promo_signup_flag,
         cohort_month,
         month_offset  
;