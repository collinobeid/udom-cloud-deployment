\# UDOM Cloud Database, Storage, Backup and Monitoring





\# 1. Database Architecture



UDOM Cloud uses MariaDB 10.11 as the Nextcloud database.



Docker service:



db



Database storage:



db\_data:/var/lib/mysql



The database stores Nextcloud application data such as:



\- users

\- files metadata

\- sharing information

\- application configuration

\- authentication-related records

\- task processing records

\- application data



\---



\# 2. Storage Architecture



The deployment uses persistent Docker volumes.



\## MariaDB



db\_data



Purpose:



Persistent MariaDB database storage.



\## Nextcloud



nextcloud\_data



Purpose:



Persistent Nextcloud application and user data.



\## Ollama



ollama\_data



Purpose:



Persistent local AI model storage.



\---



\# 3. Database Backup



The database backup process uses MariaDB dump.



Script:



scripts/backup\_database.sh



The backup is compressed using gzip.



Example:



nextcloud\_db\_2026-08-27\_12-00-00.sql.gz



Backup location:



/var/backups/udom-cloud/



The backup contains the Nextcloud database and is intended for disaster recovery.



\---



\# 4. Nextcloud Data Backup



Nextcloud persistent data is backed up using:



scripts/backup\_nextcloud.sh



The script creates a compressed archive of the persistent Nextcloud Docker volume.



\---



\# 5. Storage Monitoring



Storage is monitored using:



scripts/monitor\_storage.sh



The monitoring script checks:



\- filesystem usage

\- Docker volumes

\- Docker disk usage



A warning is generated when filesystem usage reaches 80%.



\---



\# 6. Database Monitoring



Database health is checked using:



scripts/monitor\_database.sh



The monitoring process checks:



\- MariaDB container status

\- MariaDB connectivity

\- database availability



\---



\# 7. Database Restoration



Database restoration is performed using:



scripts/restore\_database.sh



The restoration process takes a compressed SQL backup and imports it into MariaDB.



\---



\# 8. Backup and Restore Testing



A backup is considered successful only when:



1\. The backup file exists.

2\. The backup file is not empty.

3\. The archive can be read.

4\. The database can be restored successfully.



\---



\# 9. Disaster Recovery



In case of database failure:



1\. Stop affected services if necessary.

2\. Ensure MariaDB is available.

3\. Identify the latest valid database backup.

4\. Restore the database.

5\. Verify database connectivity.

6\. Start/verify Nextcloud.

7\. Verify user login.

8\. Verify files and applications.

9\. Record the recovery result.



\---



\# 10. Security



Database credentials must never be committed to GitHub.



Passwords are supplied through the server environment file.



Backup files must not be committed to the Git repository.



Production backups should be stored separately from the application server where possible.



\---



\# 11. Testing



The following tests are required:



\- Database availability test

\- Database backup test

\- Backup integrity test

\- Database restore test

\- Storage usage test

\- Docker volume verification

\- Nextcloud functionality verification



\---



