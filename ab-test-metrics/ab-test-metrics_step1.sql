----------------------------------------------------------------------------------------------------
--PART 0: CREATE OUTPUT TABLE:
----------------------------------------------------------------------------------------------------

    -- drop table if exists {ab_variant_results};
    -- create table {ab_variant_results} (
    --     testname varchar
    --     ,variation varchar
    --     ,control_description varchar
    --     ,reporting_date date
    --     ,metric_name varchar
    --     ,n_tre integer
    --     ,n_con integer
    --     ,metric_total_tre float
    --     ,metric_total_con float
    --     ,metric_normalized_tre float
    --     ,metric_normalized_con float
    --     ,variance_tre float
    --     ,variance_con float
    --     ,diff float
    --     ,diff_pct float
    -- )


----------------------------------------------------------------------------------------------------
--PART 1: IDENTIFY USERS IN EXPERIMENT
----------------------------------------------------------------------------------------------------

--First clean up old data
--(Why? Every calculation run overwrites previous calculations, so you can incorporate additional metrics or filters mid-experiment)
delete from {ab_variant_results} where testname = '{{testname}}'
;

insert into {ab_variant_results} (testname, variation, control_description, reporting_date, metric_name, n_tre, n_con, metric_total_tre, metric_total_con, metric_normalized_tre, metric_normalized_con, variance_tre, variance_con, diff, diff_pct)


--For each session, get the first time stamp the user's assigned experiment variation was logged (for every test)
--(In our implementation, an assigned_variation log fires for every user on every page view. Different assignment variation implementations allow simplification in this section)
with first_variant_logs as (
    select
        a.session_id
        ,a.testname
        ,a.variation
        ,min(a.time) as first_log_time
    from {assigned_variation} a
    where 1=1
        and date(a.time) between '{{test_start_date}}' and '{{test_end_date}}'
        and a.testname = '{{testname}}'
    group by 1,2,3
)


--Find users who visited the path(s) where the treatment exists. 
--Filter to users who were part of a test variant in that session, and attach test and variant information to the user.
--Record the first page view time as the first_exposure_time, which will be used to filter metric data later.
--(In our implementation, user_id could change. If you use a stable user_id, you can simplify this step and the previous step to use it instead of session_id)
,exposed_users as (
    select
        p.user_id
        ,v.testname
        ,v.variation
        ,min(p.time) as first_exposure_time
    from {pageviews} p
    inner join first_variant_logs v 
        on p.session_id = v.session_id
        and p.time >= v.first_log_time
    where 1=1
        and p.path in ({{exposure_paths}})
        --README: This is a good place to add additional test-specific audience filters. For example, we tested features available to users in specific states.
    group by 1,2,3
)


--For every user, make a row with every date between their first exposure to the test and the last day of the test.
--(There are probably more elegant ways to do this. Our environment was Civis Redshift.)
,experiment_dates as (
    select date(dateadd(day, n.number::integer, '{{test_start_date}}'::date)) as reporting_date
    from (
        select      --this makes a column of numbers from 0-2^6 so that we can increment single day offsets to start_date
            p0.n
            + p1.n*2
            + p2.n * power(2,2)
            + p3.n * power(2,3)
            + p4.n * power(2,4)
            + p5.n * power(2,5)
            + p6.n * power(2,6)
            as number
        from
            (select 0 as n union select 1) p0,
            (select 0 as n union select 1) p1,
            (select 0 as n union select 1) p2,
            (select 0 as n union select 1) p3,
            (select 0 as n union select 1) p4,
            (select 0 as n union select 1) p5,
            (select 0 as n union select 1) p6
    ) n
    where 1=1
        and reporting_date <= '{{test_end_date}}'
        and reporting_date <= current_date
)

,user_date_pairs as (
    select
        u.user_id
        ,u.testname
        ,u.variation
        ,u.first_exposure_time
        ,d.reporting_date
    from exposed_users u
    inner join experiment_dates d on 1=1
    where date(u.first_exposure_time) <= d.reporting_date
)


----------------------------------------------------------------------------------------------------
--PART 2: GET EVENTS USED TO CALCULATE METRICS
----------------------------------------------------------------------------------------------------

--Don't worry about filtering to test context in this section. That's what user_id and timestamps are for.

--DEFAULT METRICS:
--I recommend establishing a few metrics to be used in every experiment. These should ideally be top-line KPIs for the website.
--Even if they seem irrelevant to the treatment, you should include them to catch unintended side-effects.
--Suggestions: donations (or clicks to the donate form), volunteer shift sign ups, email submissions.
,default_events as (
    select
        e.user_id
        ,e.time as metric_time
        ,'DefaultEventName'::varchar as metric_event_name
    from {metric_events_table} e
    where 1=1
        and date(e.time) between '{{test_start_date}}' and '{{test_end_date}}'
        --Add additional filters as necessary.
        --Use a case statement for metric_event_name if multiple metrics can be derived from a single table.

    --Use union all here to add metric events from additional tables.
)


--CUSTOM METRICS:
--Add experiment-specific metric events here.  Same concept as above.
--Suggestions: Funnel step conversions, important clicks / form changes / form submits, conversion outcomes (if more granular than the defaults, e.g. if you have multiple donate button placements and are trying to optimize a specific placement)
,custom_events as (
    select
        e.user_id
        ,e.time as metric_time
        ,'CustomEventName'::varchar as metric_event_name
    from {metric_events_table} e
    where 1=1
        and date(e.time) between '{{test_start_date}}' and '{{test_end_date}}'
)


----------------------------------------------------------------------------------------------------
--PART 3: FILTER EVENTS THAT OCCURRED ONLY FOR EACH EXPOSED USER, AND AFTER EACH USER'S FIRST EXPOSURE TIME
----------------------------------------------------------------------------------------------------

--Also attach test and variant name while we're at it.
,user_metric_event_timestamps as (
    select
        u.user_id
        ,u.testname
        ,u.variation
        ,date(m.metric_time) as date
        ,m.metric_event_name || ' Rate' as metric_name
        ,null as metric_value
    from exposed_users u
    inner join default_events m
        on u.user_id = m.user_id
        and u.first_exposure_time <= m.metric_time
    group by 1,2,3,4,5

    union all
    select
        u.user_id
        ,u.testname
        ,u.variation
        ,date(m.metric_time) as date
        ,m.metric_name || ' Rate' as metric_name
        ,null as metric_value
    from exposed_users u
    inner join custom_events m
        on u.user_id = m.user_id
        and u.first_exposure_time <= m.metric_time
    group by 1,2,3,4,5
)


----------------------------------------------------------------------------------------------------
--PART 4: SUMMARIZE USER-LEVEL CUMULATIVE METRIC PROPORTIONS (i.e. 0 or 1 for each user, metric, and date)
----------------------------------------------------------------------------------------------------

--List all metric names here. Note that metric_name should be a concatenation of the event_name and ' Rate'
--This step is necessary because some users will not appear for a given metric in the default_events and custom_events subquery results, but need to be recorded as '0' for that metric.
--This script only supports 'proportion' metric types. An earlier design for the pipeline included plans to add 'Sum per User' and 'Count per User' metrics, so the metric_type concept is retained for posterity.
--README: remember to update this whenever you change default or custom metrics, and make sure metric_name strings match through script.
,metric_list as (
    select 'Proportion' as metric_type, 'DefaultEventName Rate' as metric_name
    union all
    select 'Proportion' as metric_type, 'CustomEventName Rate' as metric_name
)


--For every date a user is part of the experiment, summarize their cumulative metric result for proportion metrics.
--Cumulative means the metric event occurred at least once between the user's first exposure time and the reporting date.
,user_cumulative_proportion as (
    select
        u.user_id
        ,u.testname
        ,u.variation
        ,u.reporting_date
        ,l.metric_name
        ,max(case when m.user_id is null then 0 else 1 end) as metric_value
    from user_date_pairs u
    inner join metric_list l on 1=1
    left outer join user_metric_event_timestamps m 
        on u.user_id = m.user_id and u.testname = m.testname and u.variation = m.variation
        and u.reporting_date >= m.date
        and l.metric_name = m.metric_name
    where l.metric_type = 'Proportion'
    group by 1,2,3,4,5
)


----------------------------------------------------------------------------------------------------
--PART 5: CALCULATE VARIANT-LEVEL METRIC SUM AND VARIANCE
----------------------------------------------------------------------------------------------------

--Identify which variant is the control for each test.  Later, all treatment variants will have some metrics calculated relative to their respective control variant.
,control_variants as (
    select '{{testname}}'::varchar as testname, '{{control_variation}}'::varchar as control_variant
)


--Calculate cumulative metric proportion and variance for each variant and date. Flag control vaiant as such.
--(Our environment was Civis Redshift. You may need a different approach to calculate variance.  Variance for a proportion = squar root of [(proportion * (1-proportion) ) / n] )
,variant_stats as (
    select
        u.testname
        ,u.variation
        ,u.reporting_date
        ,case when c.control_variant is null then false else true end as is_control
        ,u.metric_name
        ,sum(u.metric_value) as metric_value
        ,var_samp(u.metric_value) as variance
    from user_cumulative_proportion u
    left outer join control_variants c 
        on u.testname = c.testname 
        and u.variation = c.control_variant
    group by 1,2,3,4,5
)


----------------------------------------------------------------------------------------------------
--PART 6: CALCULATE TREATMENT VS. CONTROL METRICS, NORMALIZE VARIANT-LEVEL STATS, AND INSERT INTO REPORTING TABLE
----------------------------------------------------------------------------------------------------

--Count number of exposed users in each variant as of each reporting date. Flag control variant as such.
,variant_n as (
    select 
        u.testname
        ,u.variation
        ,u.reporting_date
        ,case when c.control_variant is null then false else true end as is_control
        ,count(distinct u.user_id) as n
    from user_date_pairs u
    left outer join control_variants c 
        on u.testname = c.testname 
        and u.variation = c.control_variant
    group by 1,2,3,4
)

--Calculate each treatment group's results for each reporting date. Normalize per user and make comparisons to control group where needed.
--In Step 2, an R script will consume these results to generate inferential statistics.
--(the float casts may be unnecessary, but the pace of development prevented us from verifying that a more elegant solution was possible)
select
    t.testname
    ,t.variation
    ,c.variation as control_description
    ,t.reporting_date
    ,t.metric_name
    ,tn.n as n_tre
    ,cn.n as n_con
    ,t.metric_value as metric_total_tre
    ,c.metric_value as metric_total_con
    ,case
        when tn.n > 0 then t.metric_value::float / tn.n::float
        else null end
        as metric_normalized_tre
    ,case
        when cn.n > 0 then c.metric_value::float / cn.n::float
        else null end
        as metric_normalized_con
    ,t.variance as variance_tre
    ,c.variance as variance_con
    ,metric_normalized_tre::float - metric_normalized_con::float as diff
    ,case 
        when metric_normalized_con > 0 then metric_normalized_tre::float / metric_normalized_con::float - 1
        else null end
        as diff_pct
from variant_stats t                    --treatment metrics
inner join variant_stats c              --control metrics
    on  t.testname = c.testname
    and t.variation <> c.variation
    and t.reporting_date = c.reporting_date
    and t.metric_name = c.metric_name
inner join variant_n tn                 --treatment n
    on  t.testname = tn.testname
    and t.variation = tn.variation
    and t.reporting_date = tn.reporting_date
inner join variant_n cn                 --control n
    on  c.testname = cn.testname
    and c.variation = cn.variation
    and c.reporting_date = cn.reporting_date
where 1=1
    and t.is_control is false
    and c.is_control is true
    and tn.is_control is false
    and cn.is_control is true
;
