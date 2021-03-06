----------------------------------------------------------------------------------------------------
--PART 0: CREATE EVENTS TABLE AND SUMMARY TABLE
----------------------------------------------------------------------------------------------------

    --{convert_overview_events}: store conversion events categorized by dimensions of interst

    -- drop table if exists {convert_overview_events};
    -- create table {convert_overview_events} (
    --     user_id varchar
    --     ,session_id varchar
    --     ,date date
    --     ,device_type varchar
    --     ,region varchar
    --     ,state_group varchar
    --     ,page_name varchar
    --     ,page_job varchar
    --     ,channel varchar
    --     ,convert_event varchar
    -- )

    --{convert_overview_summary}: conversion count rolled up by time period and dimensions of interest
    --analysis column describes the combination of time periods and dimensions summarized

    -- drop table if exists {convert_overview_summary};
    --     create table {convert_overview_summary} (
    --         analysis varchar
    --         ,date date
    --         ,week varchar
    --         ,month varchar
    --         ,reporting_wk_yr varchar
    --         ,device_type varchar
    --         ,region varchar
    --         ,state_group varchar
    --         ,page_name varchar
    --         ,page_job varchar
    --         ,channel varchar
    --         ,convert_event varchar
    --         ,event_ct integer
    --     )

----------------------------------------------------------------------------------------------------
--PART 1: CLASSIFY CONVERT EVENTS:
----------------------------------------------------------------------------------------------------

--First clean up old date for that date to make re-runs easier
-- truncate {convert_overview_events};
delete from {convert_overview_events} 
    where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
;

insert into {convert_overview_events} (user_id, session_id, date, device_type, region, state_group, page_name, page_job, channel, convert_event)

    with events_raw as (
        select      --clicks
            e.user_id
            ,e.session_id
            ,date(e.time) as date
            ,e.device_type
            ,e.region

            --page identification:
            ,e.domain
            ,e.path

            --channel attribution:
            ,case
                when regexp_replace(regexp_substr(e.query,'\\?source=([^&]*)'), '\\?source=', '' ) <> '' then
                     regexp_replace(regexp_substr(e.query,'\\?source=([^&]*)'), '\\?source=', '' )      --when source is first query parameter
                else regexp_replace(regexp_substr(e.query,'&source=([^&]*)'), '&source=', '' ) end      --when source is not the first query parameter
                as source
            ,e.utm_medium
            ,e.utm_source
            ,e.query
            ,e.referrer
            ,'Convert Event Name'::varchar as convert_event
        from {convert_logs_source} e
        where 1=1
            and date(e.time) between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
            --Add additional filters as necessary.
            --Use a case statement for metric_event_name if multiple metrics can be derived from a single table.

        --Use union all here to add metric events from additional tables (e.g. clicks, form submits, page views)
    )

    --Replocate the dimension logic used in `reach-overview.sql` here:
    ,events_pages as (
        select
            e.user_id
            ,e.session_id
            ,e.date
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

            --channel attribution:
            ,e.source
            ,e.utm_medium
            ,e.utm_source
            ,e.query
            ,e.referrer

            ,e.convert_event

        from events_raw e
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
                when ... then 'Internal Transfer'
                else 'Other'
                end as channel
            ,e.convert_event
        from events_pages e
        left join (select distinct source, publisher from ads_reporting.ads_sources_metadata) m on e.source = m.source
    )

    select * from events_channels
;

----------------------------------------------------------------------------------------------------
--PART 2: CREATE SUMMARIES
----------------------------------------------------------------------------------------------------

-- truncate {convert_overview_summary};
delete from {convert_overview_summary} 
    where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
;

insert into {convert_overview_summary} (analysis, date, week, month, reporting_wk_yr, device_type, region, state_group, page_name, page_job, channel, convert_event, event_ct)

    ----------------------------------------------------------------------------------------------------
    --DAILY AGGREGATES:
    ----------------------------------------------------------------------------------------------------

    select
        'Fully Segmented Events' as analysis
        ,date as date
        ,datepart(week, dateadd(day, 1, date)) as week      --redshift weeks start on monday, so this dateadd() reports weeks starting sunday
        ,datepart(month, date) as month
        ,case when date < '2018-12-30'::date then '2018' when date < '2019-12-29'::date then '2019' when date < '2021-01-03'::date then '2020' else '2021' end as reporting_wk_yr
        ,device_type
        ,region
        ,state_group
        ,page_name
        ,page_job
        ,channel
        ,convert_event
        ,count(*) as event_ct
    from {convert_overview_events}
    where date between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
    group by 2,3,4,5,6,7,8,9,10,11,12



----------------------------------------------------------------------------------------------------
--TABLEAU QUERY:
----------------------------------------------------------------------------------------------------
-- select * from {convert_overview_summary}