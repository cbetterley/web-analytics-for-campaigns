----------------------------------------------------------------------------------------------------
--PART 0: CREATE EVENTS TABLE AND SUMMARY TABLE
----------------------------------------------------------------------------------------------------

    --{reach_overview_events}: store page views categorized by dimensions of interst

    -- drop table if exists {reach_overview_events};
    -- create table {reach_overview_events} (
    --     user_id varchar
    --     ,session_id varchar
    --     ,date date
    --     ,device_type varchar
    --     ,region varchar
    --     ,state_group varchar
    --     ,page_name varchar
    --     ,page_job varchar
    --     ,channel varchar
    -- );

    --{reach_overview_summary}: users / sessions / page views metrics rolled up by time period and dimensions of interest
    --analysis column describes the combination of time periods and dimensions summarized

    -- drop table if exists {reach_overview_summary};
    -- create table {reach_overview_summary} (
    --     analysis varchar
    --     ,date date
    --     ,week varchar
    --     ,month varchar
    --     ,reporting_wk_yr varchar
    --     ,device_type varchar
    --     ,region varchar
    --     ,state_group varchar
    --     ,page_name varchar
    --     ,page_job varchar
    --     ,channel varchar
    --     ,pv_ct integer
    --     ,session_ct integer
    --     ,user_ct integer
    -- );

----------------------------------------------------------------------------------------------------
--PART 1: CLASSIFY PAGE VIEWS
----------------------------------------------------------------------------------------------------

--First clean up old date for that date to make re-runs easier
-- truncate {reach_overview_events};
delete from {reach_overview_events} 
    where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
;

--For each page view, extract important columns and and apply logic to create dimensions of interest
--In our implementation, it was easier to perform this in two steps, with channel classification occurring last. You may be able to simplify.
insert into {reach_overview_events} (user_id, session_id, date, device_type, region, state_group, page_name, page_job, channel)

    with events as (
        select
            e.user_id
            ,e.session_id
            ,date(e.time) as date
            ,e.device_type
            ,e.region
            ,case
                when e.region in ('Iowa', 'New Hampshire', 'South Carolina', 'Nevada') then 'Early'
                when e.region in ('Alabama', 'Arkansas', 'California', 'Colorado', 'Maine', 'Massachusetts', 'Minnesota', 'North Carolina', 'Oklahoma', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia') then 'Super Tuesday'
                when e.region in ('Idaho', 'Michigan', 'Mississippi', 'Missouri', 'North Dakota', 'Washington') then 'March 10'
                when e.region in ('Wyoming', 'Arizona', 'Florida', 'Illinois', 'Ohio', 'Georgia', 'North Dakota') then 'March 14-27'
                else 'Other' end
                as state_group

            --page identification:
            ,case

                --Gateway:
                when e.domain = 'elizabethwarren.com' and e.path = '/' then 'Home'
                
                --Learn:
                when e.domain = 'elizabethwarren.com' and e.path like '/meet-elizabeth%' then 'Meet Elizabeth'
                when e.domain = 'elizabethwarren.com' and e.path in ('/plans','/plans/') then 'Plans Gateway'
                when e.domain = 'elizabethwarren.com' and e.path like '/plans/%' then 'Plan Detail'
                when e.domain = 'elizabethwarren.com' and e.path like '/issues%' then 'Issues'
                when e.domain = 'elizabethwarren.com' and (e.path like '%/calculator%' 
                                                        or e.path like '/debt%'
                                                        or e.path like '/kids%'
                                                        or e.path like '/retirement%'
                                                        ) then 'Calculators'
                when e.domain = 'elizabethwarren.com' and e.path like '/tax-returns%' then 'Tax Returns'
                when e.domain = 'elizabethwarren.com' and e.path like '/faqs%' then 'FAQ'
                when e.domain = 'elizabethwarren.com' and e.path like '/wealth-gap%' then 'Wealth Gap (Scrolly Telling)'
                when e.domain = 'elizabethwarren.com' and e.path like '/live%' then 'Live'
                when e.domain = 'elizabethwarren.com' and e.path like '/watch-live%' then 'Live'
                when e.domain = 'elizabethwarren.com' and e.path like '/legal-work%' then 'Legal Work'
                when e.domain = 'elizabethwarren.com' and e.path like '/pocahontas%' then 'Pocahontas'
                when e.domain = 'learn.elizabethwarren.com' then 'learn.ew domain (all)'

                --Volunteer:
                when e.domain = 'elizabethwarren.com' and e.path like '/join-us%' then 'Join Us'
                when e.domain = 'elizabethwarren.com' and e.path like '/all-in-for-warren%' then 'All In For Warren'
                when e.domain = 'elizabethwarren.com' and e.path like '/take-action%' then 'Take Action'
                when e.domain = 'elizabethwarren.com' and e.path like '/volunteer%' then 'Volunteer'
                when e.domain = 'elizabethwarren.com' and e.path like '/toolkit%' then 'Toolkit'
                when e.domain = 'elizabethwarren.com' and e.path like '/call%'then 'Call'
                when e.domain = 'elizabethwarren.com' and lower(e.path) like '/roadwarriors%' then 'Road Warriors'
                when e.domain = 'events.elizabethwarren.com' and e.path = '/' then 'events.ew: Events Gateway'
                when e.domain = 'events.elizabethwarren.com' and e.path like '/event/%' then 'events.ew: Event Detail'
                when e.domain = 'events.elizabethwarren.com' then 'events.ew: Other'
                when e.domain = 'switchboard.elizabethwarren.com' then 'Switchboard'
                when e.domain = 'elizabethwarren.com' and e.path like '/jobs%' then 'Jobs'
                when e.domain = 'join.elizabethwarren.com' then 'join.ew domain (all)'

                --Donate:
                when e.domain = 'donate.elizabethwarren.com' then 'donate.ew domain (all)'
                when e.domain = 'elizabethwarren.com' and e.path like '/thanks-for-donating%' then 'Thanks For Donating'
                when e.domain = 'elizabethwarren.com' and e.path like '/give-by-mail%' then 'Give By Mail'
                when e.domain = 'secure.actblue.com' then 'ActBlue'

                --GOTV/C:
                when e.domain = 'caucus-app.elizabethwarren.com' then 'caucus-app.ew domain (all)'
                when e.domain = 'elizabethwarren.com' and e.path like '/vote%' then 'Polling Locator'
                when e.domain = 'elizabethwarren.com' and e.path like '/pledge%' then 'Pledge'

                --Shop:
                when e.domain = 'shop.elizabethwarren.com' then 'Shop'

                --Miscellaneous:
                when e.domain = 'elizabethwarren.com' and e.path like '/es%' then 'En Espanol (all ew.com/es/)'
                when e.domain = 'elizabethwarren.com' and (e.path like '/privacy-policy%' or e.path like '/terms-of-service%') then 'Privacy Policy, TOS'
                when e.domain = 'elizabethwarren.com' and e.path like '/contact-us%' then 'Contact Us'
                when e.domain = 'elizabethwarren.com' and e.path like '/grassroots-donor-wall%' then 'Grassroots Donor Wall'
                when e.domain = 'facts.elizabethwarren.com' then 'Fact Squad'
                when e.domain = 'my.elizabethwarren.com' and (e.path like '%unsubscribe%' or e.path in ('/page/s/less-email','/page/st/less-email'))then 'Email Unsubscribe / Reduce'
                when e.domain = 'my.elizabethwarren.com' and (e.path like '%/page/s/%' or e.path like '%/page/st/%' or e.path like '%/page/sp/%') then 'Surveys / Petitions / Contests'
                when e.domain = 'my.elizabethwarren.com' then 'Other my.ew.com'

                else 'Unclassified' end
                as page_name
            
            --page job groups:
            --(these case statements should be the same as page_name, except for the result string)
            ,case

                --Gateway:
                when e.domain = 'elizabethwarren.com' and e.path = '/' then 'Gateway'
                
                --Learn:
                when e.domain = 'elizabethwarren.com' and e.path like '/meet-elizabeth%' then 'Learn'
                when e.domain = 'elizabethwarren.com' and e.path in ('/plans','/plans/') then 'Learn'
                when e.domain = 'elizabethwarren.com' and e.path like '/plans/%' then 'Learn'
                when e.domain = 'elizabethwarren.com' and e.path like '/issues%' then 'Learn'
                when e.domain = 'elizabethwarren.com' and (e.path like '%/calculator%' 
                                                        or e.path like '/debt%'
                                                        or e.path like '/kids%'
                                                        or e.path like '/retirement%'
                                                        ) then 'Learn'
                when e.domain = 'elizabethwarren.com' and e.path like '/tax-returns%' then 'Learn'
                when e.domain = 'elizabethwarren.com' and e.path like '/faqs%' then 'Learn'
                when e.domain = 'elizabethwarren.com' and e.path like '/wealth-gap%' then 'Learn'
                when e.domain = 'elizabethwarren.com' and e.path like '/live%' then 'Learn'
                when e.domain = 'elizabethwarren.com' and e.path like '/watch-live%' then 'Learn'
                when e.domain = 'elizabethwarren.com' and e.path like '/legal-work%' then 'Learn'
                when e.domain = 'elizabethwarren.com' and e.path like '/pocahontas%' then 'Learn'
                when e.domain = 'learn.elizabethwarren.com' then 'Learn'

                --Volunteer:
                when e.domain = 'elizabethwarren.com' and e.path like '/join-us%' then 'Volunteer'
                when e.domain = 'elizabethwarren.com' and e.path like '/all-in-for-warren%' then 'Volunteer'
                when e.domain = 'elizabethwarren.com' and e.path like '/take-action%' then 'Volunteer'
                when e.domain = 'elizabethwarren.com' and e.path like '/volunteer%' then 'Volunteer'
                when e.domain = 'elizabethwarren.com' and e.path like '/toolkit%' then 'Volunteer'
                when e.domain = 'elizabethwarren.com' and e.path like '/call%'then 'Volunteer'
                when e.domain = 'elizabethwarren.com' and lower(e.path) like '/roadwarriors%' then 'Volunteer'
                when e.domain = 'events.elizabethwarren.com' and e.path = '/' then 'Volunteer'
                when e.domain = 'events.elizabethwarren.com' and e.path like '/event/%' then 'Volunteer'
                when e.domain = 'events.elizabethwarren.com' then 'Volunteer'
                when e.domain = 'switchboard.elizabethwarren.com' then 'Volunteer'
                when e.domain = 'elizabethwarren.com' and e.path like '/jobs%' then 'Volunteer'
                when e.domain = 'join.elizabethwarren.com' then 'Volunteer'

                --Donate:
                when e.domain = 'donate.elizabethwarren.com' then 'Donate'
                when e.domain = 'elizabethwarren.com' and e.path like '/thanks-for-donating%' then 'Donate'
                when e.domain = 'elizabethwarren.com' and e.path like '/give-by-mail%' then 'Donate'
                when e.domain = 'secure.actblue.com' then 'Donate'

                --GOTV/C:
                when e.domain = 'caucus-app.elizabethwarren.com' then 'GOTV/C'
                when e.domain = 'elizabethwarren.com' and e.path like '/vote%' then 'GOTV/C'
                when e.domain = 'elizabethwarren.com' and e.path like '/pledge%' then 'GOTV/C'

                --Shop:
                when e.domain = 'shop.elizabethwarren.com' then 'Shop'

                --Miscellaneous:
                when e.domain = 'elizabethwarren.com' and e.path like '/es%' then 'Miscellaneous'
                when e.domain = 'elizabethwarren.com' and (e.path like '/privacy-policy%' or e.path like '/terms-of-service%') then 'Miscellaneous'
                when e.domain = 'elizabethwarren.com' and e.path like '/contact-us%' then 'Miscellaneous'
                when e.domain = 'elizabethwarren.com' and e.path like '/grassroots-donor-wall%' then 'Miscellaneous'
                when e.domain = 'facts.elizabethwarren.com' then 'Miscellaneous'
                when e.domain = 'my.elizabethwarren.com' and (e.path like '%unsubscribe%' or e.path in ('/page/s/less-email','/page/st/less-email'))then 'Miscellaneous'
                when e.domain = 'my.elizabethwarren.com' and (e.path like '%/page/s/%' or e.path like '%/page/st/%' or e.path like '%/page/sp/%') then 'Miscellaneous'
                when e.domain = 'my.elizabethwarren.com' then 'Miscellaneous'

                else 'Unclassified' end
                as page_job

            --ingredients for channel attribution:
            ,case
                when regexp_replace(regexp_substr(e.query,'\\?source=([^&]*)'), '\\?source=', '' ) <> '' then
                     regexp_replace(regexp_substr(e.query,'\\?source=([^&]*)'), '\\?source=', '' )      --when source is first query parameter
                else regexp_replace(regexp_substr(e.query,'&source=([^&]*)'), '&source=', '' ) end      --when source is not the first query parameter
                as source
            ,e.utm_medium
            ,e.utm_source
            ,e.query
            ,e.referrer
        from heap.pageviews e
        where 1=1
            and date(e.time) between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
            --Add any other useful filters here. Suggestions: domain, staff exclusion logic
    )

    ,events_channels as (
        select
            e.user_id
            ,e.session_id
            ,e.date
            ,e.device_type
            ,e.region
            ,e.state_group
            ,e.page_name
            ,e.page_job
            
            --channel attribution:
            --(in our implementation, we used a combination of source / utm / referrer in a case statement, joined to a metadata table owned by ads for some parts)
            --(we had to manually maintain this case statement. Best practice would be to have all traffic-generating teams maintain metadata tables and join to that with a much simpler case statement instead)
            ,case
                when ... then 'Paid Search'
                when ... then 'Display'
                when ... then 'Paid Direct Buy'
                when ... then 'Paid Direct Buy'
                when ... then 'Paid Social'
                when ... then 'Email'
                when ... then 'Affiliate'
                when ... then 'Organic Search'
                when ... then 'Organic Social'
                when ... then 'SMS'
                when ... then 'Unknown Channel'
                when ... then 'Direct'
                when ... then 'Internal Transfer'       --Internal transfers: when the traffic reaches our website via a fundraising form or the shop with no other channel attribution. Mostly Thanks for Donating page views.
                else 'Other'                            --Other should only be a few percentage points. Monitor it periodically - an increase means you should audit your sourcing logic and verify traffic-generating teams are following it
                end as channel
        from events e
    )

    select * from events_channels
;

----------------------------------------------------------------------------------------------------
--PART 2: CREATE SUMMARIES
----------------------------------------------------------------------------------------------------

-- truncate {reach_overview_summary};
delete from {reach_overview_summary} 
    where(
        (analysis = 'Fully Segmented PVs' and date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)) or 
        (analysis like 'Daily%' and date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)) or
        (analysis like 'Weekly%') or
        (analysis like 'Monthly%')
    )   
;

insert into {reach_overview_summary} (analysis, date, week, month, reporting_wk_yr, device_type, region, state_group, page_name, page_job, channel, pv_ct, session_ct, user_ct)

    ----------------------------------------------------------------------------------------------------
    --DAILY AGGREGATES:
    ----------------------------------------------------------------------------------------------------

    select
        'Fully Segmented PVs' as analysis
        ,date as date
        ,datepart(week, dateadd(day, 1, date)) as week      --redshift weeks start on monday, so this dateadd() reports weeks starting sunday
        ,datepart(month, date) as month
        --This is a horrible way to conform years to the output we desired for our report, but it works:
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,device_type
        ,region
        ,state_group
        ,page_name
        ,page_job
        ,channel
        ,count(*) as pv_ct
        ,null::integer as session_ct
        ,null::integer as user_ct
    from {reach_overview_events} where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Daily Device Summary' as analysis
        ,date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,datepart(month, date) as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events} where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Daily State Summary' as analysis
        ,date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,datepart(month, date) as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,region
        ,state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events} where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Daily State Group Summary' as analysis
        ,date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,datepart(month, date) as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,null as region
        ,state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events} where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Daily Page Job Summary' as analysis
        ,date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,datepart(month, date) as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events} where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Daily Specific Page Summary' as analysis
        ,date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,datepart(month, date) as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,page_name
        ,page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events} where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Daily Channel Summary' as analysis
        ,date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,datepart(month, date) as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,null as page_job
        ,channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events} where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Daily Grand Total' as analysis
        ,date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,datepart(month, date) as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events} where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
    group by 2,3,4,5,6,7,8,9,10,11

    ----------------------------------------------------------------------------------------------------
    --WEEKLY AGGREGATES:
    --same as above, except date group bys
    ----------------------------------------------------------------------------------------------------
    union all
    select
        'Weekly Device Summary' as analysis
        ,null::date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,null::integer as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Weekly State Summary' as analysis
        ,null::date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,null::integer as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,region
        ,state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Weekly State Group Summary' as analysis
        ,null::date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,null::integer as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,null as region
        ,state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Weekly Page Job Summary' as analysis
        ,null::date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,null::integer as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Weekly Specific Page Summary' as analysis
        ,null::date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,null::integer as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,page_name
        ,page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Weekly Channel Summary' as analysis
        ,null::date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,null::integer as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,null as page_job
        ,channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Weekly Grand Total' as analysis
        ,null::date as date
        ,datepart(week, dateadd(day, 1, date)) as week
        ,null::integer as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    ----------------------------------------------------------------------------------------------------
    --MONTHLYLY AGGREGATES:
    --same as above, except date group bys
    ----------------------------------------------------------------------------------------------------
    union all
    select
        'Monthly Device Summary' as analysis
        ,null::date as date
        ,null::integer as week
        ,datepart(month, date) as month
        ,null::varchar as reporting_wk_yr
        ,device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Monthly State Summary' as analysis
        ,null::date as date
        ,null::integer as week
        ,datepart(month, date) as month
        ,null::varchar as reporting_wk_yr
        ,null device_type
        ,region
        ,state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Monthly State Group Summary' as analysis
        ,null::date as date
        ,null::integer as week
        ,datepart(month, date) as month
        ,null::varchar as reporting_wk_yr
        ,null device_type
        ,null as region
        ,state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Monthly Page Job Summary' as analysis
        ,null::date as date
        ,null::integer as week
        ,datepart(month, date) as month
        ,null::varchar as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Monthly Specific Page Summary' as analysis
        ,null::date as date
        ,null::integer as week
        ,datepart(month, date) as month
        ,null::varchar as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,page_name
        ,page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Monthly Channel Summary' as analysis
        ,null::date as date
        ,null::integer as week
        ,datepart(month, date) as month
        ,null::varchar as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,null as page_job
        ,channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11

    union all
    select
        'Monthly Grand Total' as analysis
        ,null::date as date
        ,null::integer as week
        ,datepart(month, date) as month
        ,null::varchar as reporting_wk_yr
        ,null device_type
        ,null as region
        ,null as state_group
        ,null as page_name
        ,null as page_job
        ,null as channel
        ,count(*) as pv_ct
        ,count(distinct session_id) as session_ct
        ,count(distinct user_id) as user_ct
    from {reach_overview_events}
    group by 2,3,4,5,6,7,8,9,10,11


----------------------------------------------------------------------------------------------------
--TABLEAU QUERY:
----------------------------------------------------------------------------------------------------
-- select * from {reach_overview_summary}