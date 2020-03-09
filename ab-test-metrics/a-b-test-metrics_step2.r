# goal: perform hypothesis test on data in {ab_variant_results}
# use two-tailed hypothesis test with 95% confidence level

library(tidyverse)
library(civis)

query <- sql('{ab_variant_results}')
database <- '{Your Database Name}'

df_results <- read_civis(query, database)

df_inference <- df_results %>%
    mutate(
        standard_error = sqrt((variance_tre / n_tre) + (variance_con / n_con))
        ,margin_of_error = qnorm(.975) * standard_error
        ,confidence_interval_lower = diff - margin_of_error
        ,confidence_interval_upper = diff + margin_of_error
        ,test_statistic = diff / standard_error
        ,p_value = pnorm(-1 * abs(test_statistic)) * 2
        ,mde_80 = standard_error * qnorm(.975) + standard_error * qnorm(0.80)
        ,mde_90 = standard_error * qnorm(.975) + standard_error * qnorm(0.90)
        ,mde_95 = standard_error * qnorm(.975) + standard_error * qnorm(0.95)
    )

write_civis(df_inference, tablename = '{ab_variant_inference}', if_exists = 'truncate')