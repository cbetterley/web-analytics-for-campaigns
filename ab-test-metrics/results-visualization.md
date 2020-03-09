# Visualizing AB Test Results

We created a Tableau report to visualize the data in {ab_variant_inference} and made it available to all experiment owners, developers, and analysts.  The report consists of the following:

## Filters

Test Name

Reporting Date: Present cumulative metrics as of this date.  The audience should usually look at the current date or the end date of a test.

Metrics: optional.  Useful if an experiment includes a lot of metrics and the audience wants to analyze or screenshot a subset.

## Variants:  

Show names of all treatment variants with exposed user count.  Additional column with number of exposed users in the Control variant.

## Cumulative Metrics

Per user metricsc (one row per metric-treatment pair).

Statistics:  p-value, difference, confidence intervals, MDE (80%), metric value per user (treatment & control).

Statistically significant metrics are color coded red or green depending on the sign of the difference.

On hover, the audience can read a verbose interpretation of the metrics (particularly p-value and MDE).  We implemented this using a calculated field with the following formula:

```
if [Significant?] = true then
"SIGNIFICANT: The Treatment performed significantly better/worse than the Control.  We are 95% confident that the size of this effect is between " + LEFT(STR(ROUND([Confidence Interval Lower],4)),FIND(STR(ROUND([Confidence Interval Lower],4)),".")+4) + " and " + LEFT(STR(ROUND([Confidence Interval Upper],4)),FIND(STR(ROUND([Confidence Interval Upper],4)),".")+4) + ".  The difference observed was " + LEFT(STR(ROUND([Difference #],4)),FIND(STR(ROUND([Difference #],4)),".")+4) + ", or " + LEFT(STR(ROUND([Difference %]*100,2)),FIND(STR(ROUND([Difference %]*100,2)),".")+2) + "% more/less than Control."
elseif [Significant?] = false then
"NOT SIGNIFICANT: We cannot conclude that the Treatment is better/worse than the Control.  We are 95% confident that the size of this effect is between " + LEFT(STR(ROUND([Confidence Interval Lower],4)),FIND(STR(ROUND([Confidence Interval Lower],4)),".")+4) + " and " + LEFT(STR(ROUND([Confidence Interval Upper],4)),FIND(STR(ROUND([Confidence Interval Upper],4)),".")+4) + ".  This doesn't mean there is NO effect: at this sample size, we only have enough data to detect effect sizes greater than +/- " + LEFT(STR(ROUND([MDE (80% Power)],4)),FIND(STR(ROUND([MDE (80% Power)],4)),".")+4) + " (MDE).  In other words, a smaller +/- effect could exist, we just don't see it yet."
else null end
```

There is a lot of inelegant logic in this implementation to address floating point rounding issues.  A more elegant solution may be possible if rounding is performed before inserting results into the results table.  We did not attempt to address this given the need to iterate quickly and move on to other projects.


## Daily Graphs

P-value by metric and variant.  Helpful for identifying / demonstrating false positives that occurred early in a multi-day experiment.

Daily Cumulative Users.  Helpful for identifying logging issues, and identifying if an experiment was actually terminated before the {{test_end_date}} expected.

Daily Cumulative Metric Value (one for treatment, one for control).  In theory, also useful for reducing false posives, but we did not end up using it.  This would be more valuable in experiments that include sum or count metrics (not just proportions), since the graphs could help with identifying outliers.