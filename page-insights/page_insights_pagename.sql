----------------------------------------------------------------------------------------------------
--PART 0: CREATE TABLES
----------------------------------------------------------------------------------------------------

        -- drop table if exists {page_insights__pv__pagename};
        -- create table {page_insights__pv__pagename} (
        --     user_id varchar
        --     ,session_id varchar
        --     ,time timestamp
        --     ,date date
        --     ,device_type varchar
        --     ,region varchar
        --     ,state_group varchar
        --     ,channel varchar
        --     ,landing_page varchar
        --     ,session_pv_seq smallint
        --     )
        --     distkey(session_id)
        --     sortkey(session_id,time)
        -- ;   

        -- drop table if exists {page_insights__conversion__pagename};
        -- create table {page_insights__conversion__pagename} (
        --     session_id varchar
        --     ,date date
        --     ,pv_time timestamp
        --     ,event_type varchar
        --     ,event_name varchar
        --     ,event_description varchar
        --     ,device_type varchar
        --     ,region varchar
        --     ,state_group varchar
        --     ,channel varchar
        --     ,landing_page varchar
        --     )
        --     distkey(session_id)
        -- ;

        -- drop table if exists {page_insights__engagement__pagename};
        -- create table {page_insights__engagement__pagename} (
        --     session_id varchar
        --     ,date date
        --     ,pv_time timestamp
        --     ,event_type varchar
        --     ,event_name varchar
        --     ,event_description varchar
        --     ,device_type varchar
        --     ,region varchar
        --     ,state_group varchar
        --     ,channel varchar
        --     ,landing_page varchar
        --     )
        --     distkey(session_id)
        -- ;

----------------------------------------------------------------------------------------------------
--PART 1: GET PAGE VIEWS
----------------------------------------------------------------------------------------------------

truncate table {page_insights__pv__pagename};
insert into {page_insights__pv__pagename} (user_id, session_id, time, date, device_type, region, state_group, channel, landing_page, session_pv_seq)

    with events_raw as (
        select
            e.user_id
            ,e.session_id
            ,e.time
            ,date(e.time) as date
            ,e.device_type
            ,e.region
            ,e.landing_page
            
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
        from {pageviews} e
            where 1=1
                and date(e.time) between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)
                
                --README: add filters here to identify page (usually domain & path)
    )

    ,events_processed as (
        select
            e.user_id
            ,e.session_id
            ,e.time
            ,e.date
            ,e.device_type
            ,e.region

            --state group classification:
            ,case
                when e.region in ('Iowa', 'New Hampshire', 'South Carolina', 'Nevada') then 'Early'
                when e.region in ('Alabama', 'Arkansas', 'California', 'Colorado', 'Maine', 'Massachusetts', 'Minnesota', 'North Carolina', 'Oklahoma', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia') then 'Super Tuesday'
                else 'Other' end
                as state_group
            
            --channel attribution:
            ,case                                   --replicate logic from traffic-overview report
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
            ,e.landing_page

            --rank within session.  In our implementation, sessions can have more than 1 marketing channel, so in some analysis we should base session dimensions on the first page view of the session.
            ,row_number() over (partition by session_id order by time asc) as session_pv_seq
        from events_raw e
    )

    select * from events_processed
;

----------------------------------------------------------------------------------------------------
--PART 2: GET SESSIONS WITH ENGAGEMENT ON EACH FEATURE
--note: sessions spanning multiple days are counted multiple times
--each row is a session+event. Sessions with no event have 1 result, sessions with n distinct event_names have n rows. Always use count(distinct session_id) with this table.
----------------------------------------------------------------------------------------------------

truncate {page_insights__engagement__pagename};
insert into {page_insights__engagement__pagename} (session_id, date, pv_time, event_type, event_name, event_description, device_type, region, state_group, channel, landing_page)

    with events as (
        select      --clicks
            e.session_id
            ,date(e.time) as date
            ,case                       --event_type: grouping of engagement metrics to make report more readable. Examples: ATF vs. BTF, High Priority vs. Low Priority, Funnel Step 1 vs. 2 vs. 3.
                ...                     --these 3 case statements should be identical, except for the result string.
                else null end
                as event_type
            ,case                       --event_name: name of specific engagement action. Examples: Submit Zip Code, Click Accept, Advance from Step 1 to Step 2.
                ...
                else null end
                as event_name
            ,case                       --event_description: helpful string for reviewing a metric definition in a report without reviewing the code. We copy-pasted useful parts of the case statement logic here.
                ...
                else null end
                as event_description
        from {convert_and_engagement_logs_source} e
        where 1=1
                and date(e.time) between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)

                --README: add filters here to identify page (usually domain & path)

                --README: add filters here.  Each or condition should match 1:1 with the 3 case statements in the select.
                and (
                    () or
                    ... or
                    ()
                )

        --README: Use union all here to add metric events from additional tables (e.g. clicks, form submits, page views)
    )

    ,sessions_and_events as (
        select
            p.session_id
            ,p.date
            ,p.time as pv_time
            ,e.event_type
            ,e.event_name
            ,e.event_description
            ,p.device_type
            ,p.region
            ,p.state_group
            ,p.channel
            ,p.landing_page
        from {page_insights__pv__pagename} p 
        left outer join events e on p.session_id = e.session_id 
        where 1=1
            and p.session_pv_seq = 1        --use session info based on first pageview on page of interest
    )

    select * from sessions_and_events
;


----------------------------------------------------------------------------------------------------
--PART 3: GET SESSIONS WITH CONVERT INTENT AFTER THE FIRST PAGE VIEW
--note: sessions spanning multiple days are counted multiple times
--each row is a session+event. Sessions with no event have 1 result, sessions with n distinct event_names have n rows. Always use count(distinct session_id) with this table.
----------------------------------------------------------------------------------------------------

truncate {page_insights__conversion__pagename};
insert into {page_insights__conversion__pagename} (session_id, date, pv_time, event_type, event_name, event_description, device_type, region, state_group, channel, landing_page)

    with events as (
        select      --clicks
            e.session_id
            ,e.time
            ,'Core Conversion' as event_type
            ,case
                ...
                else null end
                as event_name
            ,'N/A' as event_description
        from {convert_and_engagement_logs_source} e
        where 1=1
            and date(e.time) between dateadd(day, {{date_begin_offset}}, current_date) and dateadd(day, {{date_end_offset}}, current_date)

            --README: add a domain filter here if needed, but do NOT add a path filter.  Core Conversion metrics should capture behavior that occurs any time after visiting the page in the same session.

            --README: add filters here.  Each or condition should match 1:1 with the 3 case statements in the select.
            and (
                () or
                ... or
                ()
            )

        --README: Use union all here to add metric events from additional tables (e.g. clicks, form submits, page views)
    )

    ,sessions_and_events as (
        select
            p.session_id
            ,p.date
            ,p.time as pv_time
            ,e.event_type
            ,e.event_name
            ,e.event_description
            ,p.device_type
            ,p.region
            ,p.state_group
            ,p.channel
            ,p.landing_page
        from {page_insights__pv__pagename} p 
        left outer join events e 
            on p.session_id = e.session_id 
            and p.time <= e.time            --conversion event must occur after first page view on page of interest
        where 1=1
            and p.session_pv_seq = 1        --use session info based on first pageview on page of interest
    )

    select * from sessions_and_events

----------------------------------------------------------------------------------------------------
--TABLEAU QUERIES:
--page-reach:
--select * from {page_insights__pv__pagename}
--
--page-engagement-convert:
-- select * from {page_insights__engagement__pagename}
-- union all
-- select * from {page_insights__conversion__pagename}
----------------------------------------------------------------------------------------------------