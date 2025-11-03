## code to prepare `example_events` dataset goes here

example_events <-
  data.frame(
    personid = 1:40,
    index_date = lubridate::ymd(
      "2025-09-03",
      "2025-04-19",
      "2025-09-10",
      "2025-07-08",
      "2025-07-24",
      "2025-08-08",
      "2025-04-17",
      "2025-02-03",
      "2025-08-18",
      "2025-10-04",
      "2025-06-17",
      "2025-04-12",
      "2025-02-08",
      "2025-01-23",
      "2025-11-27",
      "2025-06-01",
      "2025-10-29",
      "2025-09-11",
      "2025-11-07",
      "2025-11-03",
      "2025-01-11",
      "2025-08-07",
      "2025-09-26",
      "2025-07-19",
      "2025-03-26",
      "2025-05-05",
      "2025-11-04",
      "2025-11-17",
      "2025-01-07",
      "2025-02-17",
      "2025-01-20",
      "2025-07-13",
      "2025-10-02",
      "2025-08-02",
      "2025-11-02",
      "2025-06-13",
      "2025-02-15",
      "2025-06-09",
      "2025-01-25",
      "2025-08-23"
    )
  )


set.seed(234345)

example_events <-
  example_events |>
  # Randomly add some time to the index. For some of these, allow no time to elapse.
  tidytable::mutate(
    ablation_date =
      index_date + lubridate::days(sample(x = 0:30, size = length(index_date), replace = TRUE)),

    cied_date =
      index_date + lubridate::days(sample(x = 0:90, size = length(index_date), replace = TRUE)),

    death_date =
      index_date + lubridate::days(sample(x = 1:700, size = length(index_date), replace = TRUE)),

    followup_date =
      index_date + lubridate::days(sample(x = 60:365, size = length(index_date), replace = TRUE)),

    readmit_date =
      index_date + lubridate::days(sample(x = 0:365, size = length(index_date), replace = TRUE)),

    end_of_study = max(followup_date)
  ) |>
  # Randomly replace some of these dates with NA.
  tidytable::mutate(
    tidytable::across(
      c(ablation_date, cied_date, readmit_date),

      function(x) {
        na_at <- sample.int(length(x), size = ceiling(0.5 * length(x)))

        x[na_at] <- NA

        return(x)
      }
    ),

    tidytable::across(
      c(death_date),

      function(x) {
        na_at <- sample.int(length(x), size = ceiling(0.8 * length(x)))

        x[na_at] <- NA

        return(x)
      }
    ),

    tidytable::across(
      c(followup_date),

      function(x) {
        na_at <- sample.int(length(x), size = ceiling(0.1 * length(x)))

        x[na_at] <- NA

        return(x)
      }
    )
  ) |>
  # Clean the dates to remove impossible pairs, e.g. things happening after death.
  tidytable::mutate(
    tidytable::across(
      c(ablation_date, cied_date, followup_date, readmit_date),

      function(x) {
        tidytable::case_when(
          is.na(death_date) ~ x,
          x > death_date    ~ lubridate::NA_Date_,
          .default = x
        )
      }
    )
  )


example_events <- as.data.frame(example_events)



usethis::use_data(example_events, overwrite = TRUE)
