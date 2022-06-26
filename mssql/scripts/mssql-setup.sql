IF NOT EXISTS (SELECT NULL
FROM sys.backup_devices
WHERE  [Name] = N'pinktree' AND [Type] = 2)
EXEC sp_addumpdevice 'disk', 'pinktree', '/var/opt/mssql/backup/pinktree.bak'
;

SELECT name, type_desc, physical_name
FROM sys.backup_devices
;
