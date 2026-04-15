
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
