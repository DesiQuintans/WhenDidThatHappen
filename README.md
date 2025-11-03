
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [WhenDidThatHappen](#whendidthathappen)
  - [Installation](#installation)
- [Basic usage](#basic-usage)
  - [Built-in datasets](#built-in-datasets)
  - [Simple outcomes (e.g. `survival::survfit()`, `survival::coxph()`,
    `coxme::coxme()`)](#simple-outcomes-eg-survivalsurvfit-survivalcoxph-coxmecoxme)
  - [Composite outcomes (e.g. `survival::survfit()`,
    `survival::coxph()`,
    `coxme::coxme()`)](#composite-outcomes-eg-survivalsurvfit-survivalcoxph-coxmecoxme)
  - [Competing risks, simple and composite
    (e.g. `cmprsk::crr()`)](#competing-risks-simple-and-composite-eg-cmprskcrr)
- [Advanced usage](#advanced-usage)
  - [Units of time (the `time_units`
    argument)](#units-of-time-the-time_units-argument)
  - [Blanking periods (the `blanking`
    argument)](#blanking-periods-the-blanking-argument)
  - [Minimum observation time (the `minimum_time`
    argument)](#minimum-observation-time-the-minimum_time-argument)
  - [The `debug` argument](#the-debug-argument)
- [Implementation details](#implementation-details)
  - [Dataframe shapes for input](#dataframe-shapes-for-input)
  - [Early and late censoring](#early-and-late-censoring)
  - [Tie-breaking](#tie-breaking)

<!-- TOC end -->

# WhenDidThatHappen

<!-- badges: start -->

<!-- badges: end -->

`WhenDidThatHappen` is a package for preparing data for survival
analyses, also called time-to-event analyses. It takes your Date or
Datetime data (either as one-row-per-subject or many-rows-per-subject)
and calculates when an event(s) happened, or if the subject was
censored. The calculated output is suitable for Kaplan-Meier models, Cox
Proportional Hazards models, Competing Risks models, and others. It
supports simple and composite outcomes, with optional blanking periods
and minimum observation periods.

## Installation

You can install the development version of `WhenDidThatHappen` from
[GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("DesiQuintans/WhenDidThatHappen")
```

# Basic usage

## Built-in datasets

`WhenDidThatHappen` expects all of your Date or Datetime variables to be
in the same dataframe. It comes with two example datasets; a
one-row-per-person set (`example_events`) and a many-rows-per-person set
(`example_events_multirow`).

``` r
library(WhenDidThatHappen)

head(example_events)
#>   personid index_date ablation_date  cied_date death_date followup_date
#> 1        1 2025-09-03          <NA> 2025-10-18       <NA>    2026-06-02
#> 2        2 2025-04-19          <NA> 2025-05-16       <NA>    2025-12-31
#> 3        3 2025-09-10    2025-09-28 2025-09-22       <NA>    2026-06-17
#> 4        4 2025-07-08    2025-08-05       <NA> 2026-04-22    2026-03-18
#> 5        5 2025-07-24          <NA> 2025-09-11 2027-03-14          <NA>
#> 6        6 2025-08-08          <NA> 2025-08-19       <NA>    2026-06-09
#>   readmit_date end_of_study
#> 1   2026-08-01   2026-09-08
#> 2         <NA>   2026-09-08
#> 3         <NA>   2026-09-08
#> 4   2025-10-16   2026-09-08
#> 5   2026-05-23   2026-09-08
#> 6   2026-04-02   2026-09-08
```

## Simple outcomes (e.g. `survival::survfit()`, `survival::coxph()`, `coxme::coxme()`)

The most basic application is for a single event. Here, either a person
received an ablation, or they reached the end of the study without one.

``` r
simple_outcome <- 
  when_did_that_happen(
    data          = example_events,    # Your input dataset
    analysis      = "Ablation",        # Name of outcome. Used for names/labels.
    
    identifier    = "personid",        # Column with subject's identifier
    start_time    = "index_date",      # Each subject's start date.
    event_times   = list(
      "Ablation" = c("ablation_date")  # One outcome (Ablation) with one date.
    ),
    early_censors = c(  # Subjects are censored at their earliest date of...
      "death_date",     #  Death, or
      "end_of_study"    #  The end of the study.
    ),
    late_censors = c(   # Subjects are also censored at their last date of...
      "followup_date"   #  Clinical contact with the study team.
    )
  )

some_people <- c(1, 4, 6, 8, 16, 37, 40)  # Some `personid`s to look at.

simple_outcome[some_people, ]
#>    personid timeto_ablation outcome_ablation outcome_int_ablation
#> 1         1             272         Censored                    0
#> 4         4              28         Ablation                    1
#> 6         6             305         Censored                    0
#> 8         8               9         Ablation                    1
#> 16       16             346         Censored                    0
#> 37       37             197         Censored                    0
#> 40       40             334         Censored                    0
#>    obstime_ablation
#> 1               272
#> 4               253
#> 6               305
#> 8               109
#> 16              346
#> 37              197
#> 40              334
```

`when_did_that_happen()` produces a dataframe with these columns:

1.  The subject’s identifier, so that you can join these results with
    the rest of your data.
2.  `time_to_...`, which is the time to event.
3.  `outcome_...`, which is the outcome that happened (here as a factor
    of Censored or Ablation, with Censored always being the first
    level).
4.  `outcome_int_...`, which is the same outcome as an integer starting
    from 0 (= Censored), which some analysis packages prefer.
5.  `obstime_...`, which is the total time that the subject was under
    observation.

The column names are built from the `description`, and the columns also
receive human-readable labels:

``` r
Map(function(x) { attr(x, which = "label") }, simple_outcome)
#> $personid
#> NULL
#> 
#> $timeto_ablation
#> [1] "Time to Ablation"
#> 
#> $outcome_ablation
#> [1] "Outcome of Ablation"
#> 
#> $outcome_int_ablation
#> [1] "Outcome of Ablation"
#> 
#> $obstime_ablation
#> [1] "Total observation time for Ablation outcome"
```

## Composite outcomes (e.g. `survival::survfit()`, `survival::coxph()`, `coxme::coxme()`)

You can define a composite event by providing more than one date for an
outcome:

``` r
composite_outcome <- 
  when_did_that_happen(
    data          = example_events,
    analysis      = "Cardiac Intervention",
    
    identifier    = "personid",
    start_time    = "index_date",
    event_times   = list(
      "Cardiac Intervention" = c("ablation_date", "cied_date")
    ),
    early_censors = c(
      "death_date",
      "end_of_study"
    ),
    late_censors = c(
      "followup_date"
    )
  )

composite_outcome[some_people, ]
#>    personid timeto_cardiac.intervention outcome_cardiac.intervention
#> 1         1                          45         Cardiac Intervention
#> 4         4                          28         Cardiac Intervention
#> 6         6                          11         Cardiac Intervention
#> 8         8                           9         Cardiac Intervention
#> 16       16                         346                     Censored
#> 37       37                         197                     Censored
#> 40       40                         334                     Censored
#>    outcome_int_cardiac.intervention obstime_cardiac.intervention
#> 1                                 1                          272
#> 4                                 1                          253
#> 6                                 1                          305
#> 8                                 1                          109
#> 16                                0                          346
#> 37                                0                          197
#> 40                                0                          334
```

## Competing risks, simple and composite (e.g. `cmprsk::crr()`)

Competing risks are produced by adding more than one outcome to
`event_times`, each of which can be simple or composite:

``` r
comprisk_outcome <- 
  when_did_that_happen(
    data          = example_events,
    analysis      = "Cardiac Intervention cmp Death",
    
    identifier    = "personid",
    start_time    = "index_date",
    event_times   = list(
      "Cardiac Intervention" = c("ablation_date", "cied_date"),
      "Death"                = c("death_date")
    ),
    early_censors = c(
      "end_of_study"
    ),
    late_censors = c(
      "followup_date"
    )
  )

comprisk_outcome[some_people, ]
#>    personid timeto_cardiac.intervention.cmp.death
#> 1         1                                    45
#> 4         4                                    28
#> 6         6                                    11
#> 8         8                                     9
#> 16       16                                   346
#> 37       37                                   197
#> 40       40                                   334
#>    outcome_cardiac.intervention.cmp.death
#> 1                    Cardiac Intervention
#> 4                    Cardiac Intervention
#> 6                    Cardiac Intervention
#> 8                    Cardiac Intervention
#> 16                                  Death
#> 37                               Censored
#> 40                               Censored
#>    outcome_int_cardiac.intervention.cmp.death
#> 1                                           1
#> 4                                           1
#> 6                                           1
#> 8                                           1
#> 16                                          2
#> 37                                          0
#> 40                                          0
#>    obstime_cardiac.intervention.cmp.death
#> 1                                     272
#> 4                                     253
#> 6                                     305
#> 8                                     109
#> 16                                    464
#> 37                                    197
#> 40                                    334
```

# Advanced usage

## Units of time (the `time_units` argument)

You can ask `when_did_that_happen()` to return the results in any unit
of time you like. It defaults to units of 1 day, but you can set it to
arbitrary ones like units of 2 week, or units of 3 months. Note that
`lubridate` does not have a `months()` function, so use
`lubridate::weeks()` instead.

``` r
when_did_that_happen(
  data          = example_events,
  analysis      = "Ablation",
  
  identifier    = "personid",
  start_time    = "index_date",
  event_times   = list(
    "Ablation" = c("ablation_date")
  ),
  early_censors = c("death_date", "end_of_study"),
  late_censors  = c("followup_date"),
  
  time_units    = lubridate::weeks(4)  # Give `timeto_...` in units of 1 month.
)
```

## Blanking periods (the `blanking` argument)

In some analyses, a blanking period is added to ignore events that occur
too early. A common example in the literature is ignoring early atrial
fibrillation recurrence after surgery, because minor recurrences within
8 weeks or so are currently believed to be clinically non-significant.

This function implements blanking periods as something that ignores
*events*, but does not ignore *censoring*; if your blanking period is 3
months, and a subject gets an event in 1 month and then dies at 2
months, the event will be ignored but the person will receive an outcome
of Censored and a time-to-event of 2 months.

``` r
when_did_that_happen(
  data          = example_events,
  analysis      = "Ablation",
  
  identifier    = "personid",
  start_time    = "index_date",
  event_times   = list(
    "Ablation" = c("ablation_date")
  ),
  early_censors = c("death_date", "end_of_study"),
  late_censors  = c("followup_date"),
  
  time_units    = lubridate::weeks(4),  # Give `timeto_...` in units of 1 month.
  blanking      = lubridate::weeks(1)   # A 1week post-index blanking period.
)
```

## Minimum observation time (the `minimum_time` argument)

You may require subjects to be in your study long enough to have had a
chance to develop the failure type you’re trying to investigate. You can
do this by setting the `minimum_time` argument; anyone who has less than
this amount of time in the study becomes `NA` for the analysis.

This function calculates observation time as the length of time from the
index date to the subject’s earliest censor date, regardless of whether
they had an outcome or not.

``` r
when_did_that_happen(
  data         = example_events,
  analysis      = "Ablation",
  
  identifier    = "personid",
  start_time   = "index_date",
  event_times  = list(
    "Ablation" = c("ablation_date")
  ),
  early_censors = c("death_date", "end_of_study"),
  late_censors  = c("followup_date"),
  
  time_units   = lubridate::weeks(4),  # Give `timeto_...` in units of 1 month.
  blanking     = lubridate::weeks(1),  # A 1-week post-index blanking period.
  minimum_time = lubridate::weeks(24)  # Must have ≥6 months of observation.
)
```

## The `debug` argument

Users may want to double-check what the package is doing, or investigate
odd results in their dataset. Setting `debug = TRUE` makes the package
output an extra diagnostic table.

``` r
debug_example <- 
  when_did_that_happen(
    data         = example_events,
    analysis      = "Ablation",
  
    identifier    = "personid",
    start_time   = "index_date",
    event_times  = list(
      "Ablation" = c("ablation_date")
    ),
    early_censors = c("death_date", "end_of_study"),
    late_censors  = c("followup_date"),
    
    time_units   = lubridate::weeks(4),   # Give `timeto_...` in units of 1 month.
    blanking     = lubridate::weeks(8),   # A 2-month post-index blanking period.
    minimum_time = lubridate::weeks(24),  # Must have ≥6 months of observation.
    debug = TRUE
  )

str(debug_example, 1)
#> List of 2
#>  $ Diagnostic:'data.frame':  104 obs. of  10 variables:
#>  $ Result    :'data.frame':  40 obs. of  5 variables:

head(debug_example$Diagnostic, n = 10)
#>    personid index_date .blankdate   .evtdate       .evtcol .outcome .blanked
#> 1         1 2025-09-03 2025-10-29 2026-06-02 followup_date Censored    FALSE
#> 2         1 2025-09-03 2025-10-29 2026-09-08  end_of_study Censored    FALSE
#> 3         2 2025-04-19 2025-06-14 2025-12-31 followup_date Censored    FALSE
#> 4         2 2025-04-19 2025-06-14 2026-09-08  end_of_study Censored    FALSE
#> 5         3 2025-09-10 2025-11-05 2025-09-28 ablation_date Ablation     TRUE
#> 6         3 2025-09-10 2025-11-05 2026-06-17 followup_date Censored    FALSE
#> 7         3 2025-09-10 2025-11-05 2026-09-08  end_of_study Censored    FALSE
#> 8         4 2025-07-08 2025-09-02 2025-08-05 ablation_date Ablation     TRUE
#> 9         4 2025-07-08 2025-09-02 2026-03-18 followup_date Censored    FALSE
#> 10        4 2025-07-08 2025-09-02 2026-04-22    death_date Censored    FALSE
#>    .must_start_before .followup_okay  .obstime
#> 1          2025-12-16           TRUE  9.714286
#> 2          2025-12-16           TRUE  9.714286
#> 3          2025-07-16           TRUE  9.142857
#> 4          2025-07-16           TRUE  9.142857
#> 5          2025-12-31           TRUE 10.000000
#> 6          2025-12-31           TRUE 10.000000
#> 7          2025-12-31           TRUE 10.000000
#> 8          2025-10-01           TRUE  9.035714
#> 9          2025-10-01           TRUE  9.035714
#> 10         2025-10-01           TRUE  9.035714
```

The `$Diagnostic` dataframe is the full table of each subject’s events
and censors, sorted chronologically and then by event/censor (see
Tie-breaking for more details about this). It is the last thing the
package sees before it keeps everyone’s first row, which is their
earliest post-index outcome.

# Implementation details

## Dataframe shapes for input

This function requires data in wide format, which means that the date
for each event appears in a separate column. It supports both
one-row-per-person and many-rows-per-person data.

- In one-row-per-person, it is assumed that the variables have been
  appropriately pre-processed by you. For example, you might have
  already calculated a `date_of_earliest_heart_attack`, or a
  `date_of_last_contact`, or a `study_withdrawal_date`.
  - See the included dataset `example_events` for an example of this.
- In many-rows-per-person, the variables can contain the date of every
  known event (i.e. `date_of_heart_attack`, or `date_of_survey`).
  - See the included dataset `example_events_multirow` for an example.

## Early and late censoring

To support multi-row datasets, this function handles censor dates in two
different ways.

- **Early censors** are events that censor a subject as soon as they
  happen because no new information can be collected about them, like
  when they die.
  - In a multi-row dataset, the minimum of these dates is used for each
    subject.
- **Late censors** are events that censor a subject when they **stop**
  happening, such as when they stop coming to follow-up meetings.
  - In a multi-row dataset, the maximum of these dates is used for each
    subject.

In a one-row-per-person dataset, this package assumes that you have
pre-processed the censor columns appropriately. In this case, it doesn’t
matter whether you put the dates in the `early_censors` or
`late_censors` arguments.

## Tie-breaking

Ties are common if you only have the dates of events, but not the times
of the day when they occured, e.g. a person can have a heart attack,
receive surgery for it, and pass away all in one calendar day.

This function breaks ties by first sorting the dates chronologically
**and then** sorting by the columns you provided in `event_times`,
`early_censors`, and `late_censors`, in the order that you supplied
them. This means that if an event and a censor occur at the same time,
then the person will be flagged with the event. For a call like this,
for example:

``` r
when_did_that_happen(
  [...]
  event_times  = list(
    "Cardiac Intervention" = c("ablation_date", "cied_date"),
    "CVD Death"            = c("death_date_cvd")
  ),
  early_censors = c("death_date_noncvd", "end_of_study"),
  late_censors  = c("followup_date")
  [...]
)
```

Then the sorting method is:

1.  Sort all dates chronologically, then
2.  Sub-sort by events (`ablation_date`, then `cied_date`, then
    `death_date_cvd`),
3.  Then sub-sort by early censors (`death_date_noncvd`,
    `end_of_study`),
4.  Finally, sub-sort by late censors (`followup_date`).
