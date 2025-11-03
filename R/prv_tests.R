# x <-
#   when_did_that_happen(
#     data          = test,
#     analysis_name = "Intervention cw Death",
#     identifier    = "personid",
#     start_date    = "index_date",
#     event_dates   = list(
#       "Intervention"    = c("ablation_date", "cied_date"),
#       "All-Cause Death" = c("death_date")
#     ),
#     censor_dates  = c("death_date", "followup_date", "end_of_study"),
#     time_units    = lubridate::days(7),
#     blanking      = NULL,
#     debug         = FALSE
#   )
#
# View(x[[5]], "Diagnostic")
# View(x[[6]],     "Result")
#
# when_did_that_happen(
#   data          = test,
#   analysis_name = "Intervention cw Death",
#   identifier    = "personid",
#   start_date    = "index_date",
#   event_dates   = list(
#     "Intervention"    = c("ablation_date", "cied_date"),
#     "All-Cause Death" = c("death_date")
#   ),
#   censor_dates  = c("death_date", "followup_date", "end_of_study"),
#   time_units    = lubridate::days(7),
#   blanking      = NULL
# )
