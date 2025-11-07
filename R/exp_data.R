
#' Fictional time-to-event data (one row per person)
#'
#' An invented dataset for demonstrating and testing time-to-event calculations.
#'
#' @format ## `example_events`
#' A data frame with 40 rows and 8 columns:
#' \describe{
#'   \item{personid}{Person identifier.}
#'   \item{studyarm}{Study arm.}
#'   \item{index_date}{Index date for each person.}
#'   \item{heartsurgery_date}{Date of earliest heart surgery for each person. Missing if it did not happen.}
#'   \item{lungsurgery_date}{Date of earliest lung surgery for each person. Missing if it did not happen.}
#'   \item{death_date}{Date of death for each person. Missing if they did not die.}
#'   \item{followup_date}{Last contact date for each person. Missing if they were only contacted at the beginning of the study.}
#'   \item{readmit_date}{Readmission date for each person. Missing if they were not readmitted.}
#'   \item{end_of_study}{Date of the end of the study.}
#'   ...
#' }
"example_events"



#' Fictional time-to-event data (many rows per person)
#'
#' An invented dataset for demonstrating and testing time-to-event calculations.
#' Your dataset will probably be cleaner!
#'
#' @format ## `example_events_multirow`
#' A data frame with 90 rows and 8 columns:
#' \describe{
#'   \item{personid}{Person identifier.}
#'   \item{studyarm}{Study arm.}
#'   \item{index_date}{Index date for each person.}
#'   \item{heartsurgery_date}{Date of earliest heart surgery for each person. Missing if it did not happen.}
#'   \item{lungsurgery_date}{Date of earliest lung surgery for each person. Missing if it did not happen.}
#'   \item{death_date}{Date of death for each person. All missing if they did not die.}
#'   \item{followup_date}{All dates of clinical contact for each person. All missing if they were only contacted at the beginning of the study.}
#'   \item{readmit_date}{Readmission dates for each person. All missing if they were never readmitted.}
#'   \item{end_of_study}{Date of the end of the study.}
#'   ...
#' }
"example_events_multirow"
