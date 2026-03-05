#707 outcomes
fit <- survfit(
  Surv(time,event)~strategy,
  weights=ipcw,
  data=df
)