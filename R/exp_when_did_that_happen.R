

#' Calculate time-to-event and outcomes for simple, composite, and competing events
#'
#' This function calculates the time that elapsed between a start date and the
#' earliest outcome date, and what that outcome was. It produces output that is
#' ready for survival analyses with typical R packages.
#'
#' @details
#'
#' ## Dataframe shapes for input
#'
#' This function requires data in wide format, which means that the date for
#' each event appears in a separate column. It supports both one-row-per-person
#' and many-rows-per-person data.
#'
#' - In one-row-per-person, it is assumed that the variables contain the earliest
#'   known events (i.e. `date_of_earliest_heart_attack`).
#'   - See the included dataset `example_events` for an example of this.
#' - In many-rows-per-person, the variables can contain the date of every known
#'   event (i.e. `date_of_heart_attack`). See
#'   - See the included dataset `example_events_multirow` for an example.
#'
#' @param data (Dataframe) The input data.
#' @param analysis (Character) A human-readable name for your analysis, which is used give labels to the output variables. A suffix for the final variable names will be generated from this.
#' @param identifier (Character) The name of one column in `data` that identifies subjects (e.g. patient number or machine serial number).
#' @param start_time (Character) The name of one Date/Datetime column in `data` that provides the start date of observation for each subject.
#' @param event_times (List with named Characters) Within this List, the names are human-readable labels for the event, and the contents are the names of Date/Datetime columns in `data` that are considered for that event. See 'Examples'.
#' @param early_censors (Character) The names of one or more Date/Datetime columns in `data` that are used to censor a subject as soon as they occur because no more information can be collected about them, such as death or study withdrawal. At least one censor date must be given in either this argument or in `late_censors`. If this argument is not needed, leave it as `NULL`.
#' @param late_censors (Character) The names of one or more Date/Datetime columns in `data` that are used to censor a subject when they stop occurring, such as censoring someone at their last known date of clinical contact. At least one censor date must be given in either this argument or in `early_censors`. If this argument is not needed, leave it as `NULL`.
#' @param time_units (Period) A `lubridate` Period object that describes the units of time for each time-to-event. By default, times are reported in elapsed decimal days. You may be interested in [lubridate::hours()], [lubridate::days()], [lubridate::weeks()], or [lubridate::years()]. Note that there is no function for months because the number of days in a month varies; use weeks instead.
#' @param blanking (Period) A `lubridate` Period object (like the `time_units` argument) that describes how long to wait *after* the `start_time` before observing events.
#' @param minimum_time (Period) A `lubridate` Period object that describes the minimum follow-up time required for a subject to be eligible for this analysis (they will be `NA` if ineligible).
#' @param debug (Logical) If `FALSE` (default), returns calculated results. If `TRUE`, returns diagnostic results. See 'Value'.
#'
#' @returns
#' If `debug = FALSE` (default), returns a dataframe of results.
#'
#' If `debug = TRUE`, returns a `list` with 2 elements:
#'   - `$Diagnostic` is a dataframe with all relevant dates in long format,
#'     sorted in their final decided order. Use this to inspect the dates
#'     attributed to each subject and how ties are broken.
#'   - `$Result` is the normal results dataframe.
#'
#' @export
#'
#' @examples
#' # `example_events` is an example dataset included with this package.
#'
#'
#' # Example of a simple event (Ablated or Censored), reported in units of 1 day
#' # with no blanking period or minimum follow-up requirement:
#'
#' when_did_that_happen(
#'   data          = example_events,
#'   analysis      = "My analysis",
#'
#'   identifier    = "personid",
#'   start_time    = "index_date",
#'   event_times   = list(
#'     "Heart Surgery" = c("heartsurgery_date")
#'   ),
#'   early_censors = c("death_date", "end_of_study"),
#'   late_censors  = c("followup_date"),
#'
#'   time_units    = lubridate::days(1),
#'   blanking      = lubridate::days(0),
#'   minimum_time  = lubridate::days(0),
#'
#'   debug = FALSE
#' )
#'
#'
#' # Example of a composite event (Ablated or received CIED implant, versus
#' # Censored), reported in units of 1 month with a 2 month blanking period:
#'
#' when_did_that_happen(
#'   data          = example_events,
#'   analysis      = "Any Surgery",
#'
#'   identifier    = "personid",
#'   start_time    = "index_date",
#'   event_times   = list(
#'     "Any Surgery" = c("heartsurgery_date", "lungsurgery_date")
#'   ),
#'   early_censors = c("death_date", "end_of_study"),
#'   late_censors  = c("followup_date"),
#'
#'   time_units    = lubridate::weeks(4),
#'   blanking      = lubridate::weeks(8),
#'   minimum_time  = lubridate::days(0),
#'
#'   debug = FALSE
#' )
#'
#'
#' # Example of competing risks with a composite outcome (receiving a cardiac
#' # intervention) versus a simple outcome (dying), with a blanking period
#' # of 1 month and a requirement that people must have at least 6 months of
#' # observation time in the study.
#'
#' when_did_that_happen(
#'   data          = example_events,
#'   analysis      = "Any Surgery cw Death",
#'
#'   identifier    = "personid",
#'   start_time    = "index_date",
#'   event_times   = list(
#'     "Any Surgery" = c("heartsurgery_date", "lungsurgery_date"),
#'     "Death"       = c("death_date")
#'   ),
#'   early_censors = c("end_of_study"),
#'   late_censors  = c("followup_date"),
#'
#'   time_units    = lubridate::days(1),
#'   blanking      = lubridate::weeks(4),
#'   minimum_time  = lubridate::weeks(24),
#'
#'   debug = FALSE
#' )
#'
when_did_that_happen <- function(data, analysis, identifier, start_time, event_times, early_censors = NULL, late_censors = NULL, time_units = lubridate::days(1), blanking = lubridate::days(0), minimum_time = lubridate::days(0), debug = FALSE) {

  # `data` needs to be coerced into a base data.frame, or else I get errors
  # in `aggregate()` if `data` is actually a data.table.
  data <- as.data.frame(data)


  # 0. Ensure that date inputs are clean ----------------------------------

  # Each date column must belong to one outcome only.

  .duplicated_eventcols <- unlist(event_times)[duplicated(unlist(event_times))]

  if (length(.duplicated_eventcols) > 0) {
    stop(
      "These columns appear more than once in `event_times`:\n\n",
      "  ", paste(paste0('"', .duplicated_eventcols, '"'), collapse = ", "), "\n\n",
      "List each column once only."
    )
  }


  # At least one censor column must be provided.

  .censor_count <- length(unique(c(early_censors, late_censors)))

  if (length(.censor_count) <= 0) {
    stop(
      "At least one censor date must be provided, and you provided none.\n",
      "  Early censor dates apply as soon as they happen, e.g. death.\n",
      "  Late censor dates apply when they stop happening, e.g. last contact with the patient.\n",
      "  If you don't need one of them, leave them as NULL."
    )
  }

  # `event_times` has to have at least one element in it, and that element must
  # be named and non-empty.

  if (length(unlist(event_times)) <= 0) {
    stop(
      "At least one event date must be provided, and you provided none. Provide it as:\n",
      '    event_times = list("Outcome name" = c("date_column")),'
    )
  }

  if (is.null(names(event_times))) {
    stop(
      "All outcome groups in `event_times` must be named. Provide it as:\n",
      '    event_times = list("Outcome name" = c("date_column")),'
    )
  }


  # Each censor date must be listed only once. I could `unique()` it away, but
  # forcing it to be correct in the written code is better for documentation.

  .duplicated_censorcols <- c(early_censors, late_censors)[duplicated(c(early_censors, late_censors))]

  if (length(.duplicated_censorcols) > 0) {
    stop(
      "These columns appear more than once in `early_censors` and/or `late_censors`:\n\n",
      "  ", paste(paste0('"', .duplicated_censorcols, '"'), collapse = ", "), "\n\n",
      "List each column once only."
    )
  }


  # A date column can't be used as both an outcome and a censor. The code
  # actually breaks ties correctly for this, but again, forcing it to be
  # correct in the written code is better for documentation.

  .duplicated_datecols <- intersect(unlist(event_times), c(early_censors, late_censors))

  if (length(.duplicated_datecols) > 0) {
    stop(
      "These columns appear as both events and censors:\n\n",
      "  ", paste(paste0('"', .duplicated_datecols, '"'), collapse = ", "), "\n\n",
      "The same variable cannot be an event and a censor at the same time."
    )
  }





  # 1. Set up internal functions and variables ------------------------------

  # Column names for the results columns.
  varname <- tolower(gsub("\\.{2,}", ".", make.names(analysis)))

  .timeto_colname      <- paste0("timeto_",      varname)
  .obstime_colname     <- paste0("obstime_",     varname)
  .outcome_fct_colname <- paste0("outcome_",     varname)
  .outcome_int_colname <- paste0("outcome_int_", varname)


  # Names for things.
  outcome_names <- rep(names(event_times), times = lapply(event_times, length))  # Which outcome does each event column belong to?

  .censor_name  <- "~.~.Censored.~.~"  # Placeholder value for Censored outcomes, so chosen to be unlikely to match a user's outcome name.


  # 2. Calculate early censor dates -----------------------------------------

  # Early censor dates apply as early as possible, e.g. a person is censored as
  # soon as they die. I handle them by taking the earliest in each variable for
  # each person, to make it possible for the user to provide long data.

  early_censor_dates <-
    summarise_dates(
      data       = data,
      identifier = identifier,
      outcome    = .censor_name,
      dates      = early_censors,
      FUN        = "min"
    )



  # 3. Calculate late censor dates ------------------------------------------

  # Late censor dates apply as late as possible, like when a person has many
  # dates of being contacted by study RAs, but we only censor when contact
  # is lost.

  late_censor_dates <-
    summarise_dates(
      data       = data,
      identifier = identifier,
      outcome    = .censor_name,
      dates      = late_censors,
      FUN        = "max"
    )



  # 4. Get event dates in long format -----------------------------

  # Long format is used so that the function can handle input data with many
  # rows per person (e.g. each row is a new hospital admission with a different
  # date). This is more flexible than requiring one-row-per-person input, and
  # the user can be given the long data so that they can see all of the dates
  # and verify that the code is doing what they expect.

  event_dates <-
    Reduce(
      rbind,

      Map(
        function(x, y) {
          # 1. Get the identifier and the date column in question.
          # 2. Rename the date column (.evtdate), and add new columns containing
          #    the original name of the date column (i.e. the source of the date
          #    information, .evtcol), and the outcome that this date belongs to
          #    (.outcome).
          # 3. Remove rows with missing dates and duplicated identifier * dates,
          #    and return the result.
          result <- data[, c(identifier, x)]

          names(result)[2] <- ".evtdate"
          result$.evtcol   <- x
          result$.outcome  <- y

          result <- result[!is.na(result$.evtdate), ]
          result <- result[!duplicated(result), ]

          return(result)
        },

        unlist(event_times),
        outcome_names
      )
    )

  events_and_censors <-
    rbind(
      event_dates,
      early_censor_dates,
      late_censor_dates
    )

  rownames(events_and_censors) <- NULL


  ## Check for missing censor dates -----------------------------

  .ids_with_censors <-
    unique(events_and_censors[events_and_censors[[".outcome"]] == .censor_name, ][[identifier]])

  .ids_without_censors <-
    setdiff(unique(data[[identifier]]), .ids_with_censors)

  if (length(.ids_without_censors) > 0) {
    stop(
      "These `", identifier, "` have no valid censor dates from ", paste(paste0("`", unique(c(early_censors, late_censors)), "`"), collapse = " or "), ":\n\n",
      "  ", paste(.ids_without_censors, collapse = ", "), "\n\n",
      "All subjects must have at least one censor date that is \u2265 the start date plus the blanking period (if any)."
    )
  }



  # 5. Get start dates and apply blanking rules, if any -------------------

  base_info <-
    stats::aggregate(
      x    = data[, c(start_time)],
      by   = list(data[[identifier]]),
      FUN  =
        function(vec) {
          if (all(is.na(vec))) {  # Faster + less mem_alloc than `length(vec[!is.na(vec)]) == 0`
            return(lubridate::NA_Date_)
          } else {
            return(min(vec, na.rm = TRUE))
          }
        },
      drop = FALSE
    )

  names(base_info) <- c(identifier, start_time)
  base_info[[".blankdate"]] <- base_info[[start_time]] + blanking

  rownames(base_info) <- NULL


  ## Check for missing start dates ------------------------------

  .ids_with_index <-
    unique(base_info[!is.na(base_info[[start_time]]), identifier])

  .ids_without_index <-
    setdiff(unique(data[[identifier]]), .ids_with_index)

  if (length(.ids_without_index) > 0) {
    warning(
      "These `", identifier, "` have no valid start dates from ", paste(paste0('"', start_time, '"'), collapse = " or "), ":\n\n",
      "  ", paste(.ids_without_index, collapse = ", "), "\n\n",
      "They will be NA for the derived variables."
    )
  }



  # 6. Merge event/censor dates with start dates --------------------------

  all_dates <-
    merge(
      x       = base_info,
      y       = events_and_censors,
      by      = identifier,
      sort    = FALSE,
      all     = FALSE,
      no.dups = TRUE
    )


  # Converted to a Factor so that if events are tied for the same date, the tie
  # can be broken by sorting them by the events and censors columns, in the
  # order provided by the user.
  all_dates$.evtcol <-
    factor(
      all_dates$.evtcol,
      levels = c(
        unlist(event_times),
        unique(early_censors),
        unique(late_censors)
      )
    )


  # Factor version of the outcome provided in `event_times`. Survival analysis
  # packages assume that the first level is Censored.
  all_dates$.outcome <-
    factor(
      all_dates$.outcome,
      levels = c(
        .censor_name,
        names(event_times)
      ),
      labels = c(
        "Censored",
        names(event_times)
      )
    )


  # Flag for event dates (but not censor dates) that fall within the `blanking` period.
  all_dates$.blanked <-
    (all_dates$.evtdate < all_dates[[".blankdate"]]) & (all_dates$.outcome != "Censored")


  # This is where tie-breaking happens.
  all_dates <-
    all_dates[
      order(all_dates[[identifier]],  # For each person...
            all_dates$.evtdate,       # Sort earliest dates first...
            all_dates$.evtcol),       # And break ties by sorting on the event/censor columns, in the order that they were given by the user.
    ]

  rownames(all_dates) <- NULL



  # 7. Calculate and add minimum follow-up requirements -------------------

  followup_time <-
    all_dates[all_dates$.outcome == "Censored", ]

  followup_time <-
    followup_time[!duplicated(followup_time[[identifier]]), ]

  followup_time$.must_start_before <-
    followup_time[[".evtdate"]] - minimum_time                            # Looking backwards from the earliest censor date...

  followup_time$.followup_okay <-
    followup_time[[start_time]] <= followup_time[[".must_start_before"]]  # Did they start early enough to have enough follow-up?

  followup_time$.obstime <-
    lubridate::interval(start = followup_time[[start_time]], end = followup_time[[".evtdate"]]) / time_units

  followup_time <-
    followup_time[, c(identifier, ".must_start_before", ".followup_okay", ".obstime")]



  rownames(followup_time) <- NULL


  all_dates <-
    merge(
      x       = all_dates,
      y       = followup_time,
      by      = identifier,
      sort    = FALSE,
      all     = FALSE,
      no.dups = TRUE
    )


  ## Check for missing follow-up time -------------------------------------

  .ids_with_index <-
    unique(followup_time[!is.na(followup_time[[".must_start_before"]]), identifier])

  .ids_without_index <-
    setdiff(unique(followup_time[[identifier]]), .ids_with_index)

  if (length(.ids_without_index) > 0) {
    stop(
      "These `", identifier, "` have no valid start follow-up requirement dates:\n\n",
      "  ", paste(.ids_without_index, collapse = ", "), "\n\n",
      "Check that the `minimum_time` argument is valid."
    )
  }


  # 8. Calculate final times-to-events results ----------------------------

  ## Keep rows with an index date -------------------------------

  times_to_events <- all_dates[!is.na(all_dates[[start_time]]), ]


  ## Keep rows with unblanked dates -----------------------------

  times_to_events <- times_to_events[times_to_events[[".blanked"]] == FALSE, ]


  ## Keep rows with enough follow-up ----------------------------

  # If a person has inadequate follow-up, all of their rows will be removed
  # and they will be NA in the final table.

  times_to_events <- times_to_events[times_to_events[[".followup_okay"]] == TRUE, ]


  ## Continue with first event determination --------------------

  # Keep first row for each person, which is the earliest post-index event.
  times_to_events <- times_to_events[!duplicated(times_to_events[[identifier]]), ]

  # The time-to-event calculation. Divided by `time_units` so that people can decide what units they want.
  times_to_events[[.timeto_colname]] <-
    lubridate::interval(start = times_to_events[[start_time]], end = times_to_events[[".evtdate"]]) / time_units


  # Rename the .outcome vectors and make an integer version of it for survival
  # analysis packages that want the input that way.
  names(times_to_events)[which(names(times_to_events) == ".outcome")] <- .outcome_fct_colname
  times_to_events[[.outcome_int_colname]] <- as.integer(times_to_events[[.outcome_fct_colname]]) - 1

  # Rename the .obstime vector too.
  names(times_to_events)[which(names(times_to_events) == ".obstime")] <- .obstime_colname

  # Form the final results dataframe. Keep relevant columns, remove rownames, and apply
  # human-readable labels to the variables.
  times_to_events <-
    times_to_events[
      c(
        identifier,
        .timeto_colname,
        .outcome_fct_colname,
        .outcome_int_colname,
        .obstime_colname
      )
    ]

  rownames(times_to_events) <- NULL



  # 9. Return a result, depending on desired debug behaviour --------------

  result <-
    merge(
      x       = base_info[identifier],
      y       = times_to_events,
      by      = identifier,
      sort    = TRUE,
      all     = TRUE,
      no.dups = FALSE
    )

  attr(result[[.timeto_colname]],      "label") <- paste("Time to",    analysis)
  attr(result[[.outcome_fct_colname]], "label") <- paste("Outcome of", analysis)
  attr(result[[.outcome_int_colname]], "label") <- paste("Outcome of", analysis)
  attr(result[[.obstime_colname]],     "label") <- paste("Total observation time for", analysis, "outcome")

  if (debug == TRUE) {
    return(
      list(
        "Diagnostic" = all_dates,
        "Result"     = result
      )
    )
  } else {
    return(result)
  }
}





# Supporting functions ----------------------------------------------------

# Summarises a vector of dates for each date x identifier
#
# @param data (Dataframe) The input data.
# @param identifier (Character) The name of one column in `data` that identifies subjects (e.g. patient number or machine serial number).
# @param outcome (Character) The outcome being summarised.
# @param dates (Character) The names of one or more Date/Datetime columns in `data` that are related to the same outcome.
# @param FUN (Character) The name of a function to call on `dates`. Currently accepts `"min"` (to find the earliest date per identifier), and `"max"` (the latest date).
#
# @returns A long-shaped dataframe, with a row for each identifier x date.
#
# @examples
# WhenDidThatHappen:::summarise_dates(
#   data       = example_events_multirow,
#   identifier = "personid",
#   outcome    = "Cardiac intervention",
#   dates      = c("lungsurgery_date", "heartsurgery_date"),
#   FUN        = "max"
# )
#
summarise_dates <- function(data, identifier, outcome, dates, FUN = c("min", "max")) {
  FUN <- match.arg(FUN)

  if (is.null(dates) == FALSE & length(dates) > 0) {
    dates_summary <-
      Reduce(
        rbind,

        Map(
          function(x) {
            result <-
              stats::aggregate(
                x = data[, x],
                by = list(data[[identifier]]),
                FUN =
                  function(vec) {
                    if (all(is.na(vec))) {  # Faster + less mem_alloc than `length(vec[!is.na(vec)]) == 0`
                      return(lubridate::NA_Date_)
                    } else {
                      return(eval(call(FUN, vec, na.rm = TRUE)))
                    }
                  },
                drop = FALSE
              )

            names(result) <- c(identifier, ".evtdate")
            result[[".evtcol"]]  <- x
            result[[".outcome"]] <- outcome

            result <- result[is.na(result[[".evtdate"]]) == FALSE, ]

            return(result)
          },

          dates
        )
      )
  } else {
    dates_summary <- data.frame()
  }

  rownames(dates_summary) <- NULL

  return(dates_summary)
}
