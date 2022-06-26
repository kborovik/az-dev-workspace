SELECT name, state_desc, create_date, recovery_model_desc
FROM sys.databases
WHERE name NOT IN ('master','model','msdb','tempdb')
;
