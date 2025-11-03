
#' Fictional time-to-event data (one row per person)
#'
#' An invented dataset for demonstrating and testing time-to-event calculations.
#'
#' @format ## `example_events`
#' A data frame with 40 rows and 8 columns:
#' \describe{
#'   \item{personid}{Person identifier.}
#'   \item{index_date}{Index date for each person.}
#'   \item{ablation_date}{Date of earliest ablation for each person. Missing if it did not happen.}
#'   \item{cied_date}{Date of earliest cardiac implanted electronic device implantation for each person. Missing if it did not happen.}
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
#'   \item{index_date}{Index date for each person.}
#'   \item{ablation_date}{Dates of ablation for each person. All missing if it did not happen.}
#'   \item{cied_date}{Dates of cardiac implanted electronic device implantation/revision for each person. All missing if it did not happen.}
#'   \item{death_date}{Date of death for each person. All missing if they did not die.}
#'   \item{followup_date}{All dates of clinical contact for each person. All missing if they were only contacted at the beginning of the study.}
#'   \item{readmit_date}{Readmission dates for each person. All missing if they were never readmitted.}
#'   \item{end_of_study}{Date of the end of the study.}
#'   ...
#' }
"example_events_multirow"
