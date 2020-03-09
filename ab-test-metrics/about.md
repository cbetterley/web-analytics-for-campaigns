# AB Test Metrics

## Motivation

Experiment reporting should never be a bottleneck for product iteration. Some third party tools do an excellent job at enabling this, but not all website teams have the budget to use them or the time to implement them properly. Fortunately, a data analyst can create a decision-ready, mostly-automated metrics pipeline using only SQL, R, and Tableau.

## Prerequisites

Several data warehouse resources must already be in place to use this approach. Our implementation included Heap, some custom Heap events, and Civis Platform (data warehouse & Tableau reports), but this approach is not implementation-specific. Required tables are as follows.

**{assigned_variation}**:  Table that records when users visit the site and are part of an experiment (including both first time exposures and returning visitors).  Fields must include:

- Session ID and/or User Id.  In either case, it must be able to be matched to metric events.

- Timestamp.

- Name of test.

- Name of variation (e.g. 'control', 'red button', 'large donate amounts').


**{pageviews}**:  Table that records every page view.  Fields must include:

- Session ID and/or User ID.

- Timestamp.

- Any other filter criteria used to identify the experiment audience.  Page name and domain are recommended at a minimum, since you must filter the audience to people who could have seen the treatment feature.


**{metric_events_table}**:  One or more tables storing timestamped events used to calculate metrics.  Fields must include:

- Session ID and/or User ID.

- Any other filter criteria necessary to identify metrics you want to measure.

See comments in `ab-test-metrics_step1.sql` for further discussion, including suggested metrics.

It is *not* necessary for this table to include test attribution information. In fact, this approach will not use it.

## Attribution

When a user is first exposed to a test, that user's first exposure time is recorded.

Everything that user does between first exposure time and the end of the experiment accrues to that test variant's statistics, no matter where the user behavior occurs.

Any test attribution information attached to the metric event itself is ignored. This is because the user's activity is the source-of-truth for variant membership. This dependency on the user is necessary for calculating P-Value and MDE, since those metrics are based on variance which is in turn based on user-level metric calculations.

## Hypothesis Test

The approach performs a two-tailed hypothesis test with 95% confidence level for difference in proportions between treatment and control.  We use a z-score because we have large sample sizes.  Websites with small daily traffic should consider modifying `ab-test-metrics_step2.r` to use a t-test instead.

## Parameters

The scripts include several parameters that must be updated for every experiment.  Note that these paramters are denoted with {{double braces}}, whereas table and database names are denoted with {single braces}.

**{{testname}}**: Name of the experiment. It should be a field in the table that stores variant exposure timestamps.

**{{control_variation}}**: Name of the variant considered control. It should be a field in the table that stores variant exposure timestamps. It is used to identify which variants all treatments should be compared to in difference calculations and inferential statistics.

**{{test_start_date}}**: The first day of an experiment. Not logically required, but useful for reducing the source data size.

**{{test_end_date}}**: Last expected day of the test. There is no inbuilt mechanism for stopping calculations when a test ends, so this parameter attempts to make sure the final reporting date is not diluted. Advise experiment owners to think of this as a ceiling when in doubt.

**{{exposure_paths}}**: Page(s) where the treatment exists, e.g. home page or post-donation thank you page.
