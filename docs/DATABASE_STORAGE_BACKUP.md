\# UDOM Custom Nextcloud Deployment



\## Database, Storage, Backup, Restore and Monitoring Documentation



\*\*Project:\*\* UDOM Custom Nextcloud Deployment

\*\*Repository:\*\* `collinobeid/udom-cloud-deployment`

\*\*Branch:\*\* `feature/paschal-database-storage-backup-monitoring`

\*\*Application:\*\* Nextcloud 34.0.3

\*\*Database:\*\* MariaDB 10.11

\*\*Deployment:\*\* Docker Compose

\*\*Environment:\*\* Local development/test deployment



\---



\# 1. Introduction



This document describes the database, storage, backup, restoration, and monitoring implementation for the UDOM Custom Nextcloud Deployment.



The purpose of this infrastructure is to provide a reliable foundation for the deployment of Nextcloud as an internal university cloud platform. The infrastructure supports:



\* Persistent database storage

\* Persistent Nextcloud file storage

\* Database backups

\* Nextcloud data backups

\* Database restoration

\* Nextcloud data restoration testing

\* Storage monitoring

\* Database monitoring

\* Disaster recovery preparation

\* Backup integrity verification



The implementation uses Docker Compose to provide isolated and persistent services while maintaining the ability to back up and restore important application data.



\---



\# 2. System Architecture



The deployment consists of several Docker services.



The main infrastructure components relevant to this documentation are:



```text

&#x20;                   UDOM Nextcloud Deployment

&#x20;                             |

&#x20;             +---------------+---------------+

&#x20;             |                               |

&#x20;       Nextcloud App                    MariaDB

&#x20;             |                               |

&#x20;             |                         nextcloud DB

&#x20;             |

&#x20;      nextcloud\_data volume

&#x20;             |

&#x20;             +--------------------+

&#x20;                                  |

&#x20;                           Backup Scripts

&#x20;                                  |

&#x20;                +-----------------+----------------+

&#x20;                |                                  |

&#x20;         Database Backup                  Nextcloud Data Backup

&#x20;                |                                  |

&#x20;      backups/database/                    backups/nextcloud/

&#x20;                |                                  |

&#x20;         .sql.gz archive                    .tar.gz archive

```



The deployment also contains other supporting services such as Ollama, Nextcloud AppAPI/HaRP, cron, and AI-related services.



\---



\# 3. Database Architecture



The deployment uses MariaDB as the relational database management system for Nextcloud.



\## 3.1 Database Service



The database is provided through Docker Compose using:



```text

mariadb:10.11

```



The verified MariaDB version is:



```text

10.11.19-MariaDB-ubu2204-log

```



The main database configuration is:



```text

Database name: nextcloud

Database user: nextcloud

Database type: mysql

```



Nextcloud connects to MariaDB through the Docker Compose service network rather than directly through the host machine.



\---



\# 4. Database Persistence



The MariaDB database uses a persistent Docker volume:



```text

udom-cloud-deployment\_db\_data

```



This volume ensures that the database data survives normal container recreation.



The database contains the Nextcloud application tables.



During verification, the following command was used:



```bash

docker compose exec db mariadb -u nextcloud -p nextcloud -e "SELECT DATABASE(), COUNT(\*) AS tables\_count FROM information\_schema.tables WHERE table\_schema='nextcloud';"

```



The result was:



```text

DATABASE() | tables\_count

nextcloud   | 141

```



Therefore, the Nextcloud database was confirmed to contain:



```text

141 tables

```



\---



\# 5. Database Backup



A dedicated backup script is provided:



```text

scripts/backup\_database.sh

```



The purpose of the script is to create a compressed MariaDB database dump.



The backup location is:



```text

./backups/database/

```



The generated backup format is:



```text

.sql.gz

```



Example:



```text

./backups/database/nextcloud\_db\_2026-09-10\_22-38-44.sql.gz

```



The backup is compressed using gzip to reduce storage requirements.



\---



\# 6. Database Backup Security



The database backup script does not rely on the MariaDB root account for normal application database backup operations.



Instead, it uses the configured database credentials from the Docker environment.



The Nextcloud database user has privileges on the Nextcloud database:



```text

GRANT ALL PRIVILEGES ON nextcloud.\* TO nextcloud@%

```



The backup process therefore operates against the intended application database.



Database backup files are not intended to be committed to Git because they may contain application data and credentials-related information.



The project `.gitignore` excludes the backup directory.



\---



\# 7. Database Backup Validation



A database backup was successfully generated.



Backup file:



```text

./backups/database/nextcloud\_db\_2026-09-10\_22-38-44.sql.gz

```



Approximate size:



```text

282 KB

```



The compressed archive was then checked using gzip integrity validation.



Validation result:



```text

BACKUP ARCHIVE VALID

```



The contents were also inspected and confirmed to contain an actual MariaDB SQL dump.



The backup included Nextcloud database structures such as the `oc\_accounts` table.



Therefore:



```text

Database backup: PASS

Backup archive integrity: PASS

SQL dump validation: PASS

```



\---



\# 8. Nextcloud Storage Architecture



Nextcloud application data is stored in a persistent Docker volume:



```text

udom-cloud-deployment\_nextcloud\_data

```



This volume contains the Nextcloud installation and application data required by the deployment.



The storage volume is separated from the database volume.



The main storage components are:



```text

Nextcloud application

&#x20;       |

&#x20;       v

udom-cloud-deployment\_nextcloud\_data

&#x20;       |

&#x20;       +-- config/

&#x20;       +-- data/

&#x20;       +-- apps/

&#x20;       +-- custom\_apps/

&#x20;       +-- themes/

&#x20;       +-- lib/

&#x20;       +-- version.php

&#x20;       +-- other Nextcloud files

```



Separating application storage from the database makes it possible to back up the two major data layers independently.



\---



\# 9. Nextcloud Data Backup



A dedicated backup script is provided:



```text

scripts/backup\_nextcloud.sh

```



The script creates a compressed archive of the persistent Nextcloud data volume.



Backup location:



```text

./backups/nextcloud/

```



Backup format:



```text

.tar.gz

```



Example:



```text

./backups/nextcloud/nextcloud\_data\_2026-09-10\_22-54-51.tar.gz

```



The script uses a temporary Alpine container to archive the Docker volume without modifying the live Nextcloud data.



\---



\# 10. Nextcloud Data Backup Validation



A full Nextcloud data backup was successfully created.



Backup file:



```text

./backups/nextcloud/nextcloud\_data\_2026-09-10\_22-54-51.tar.gz

```



Approximate size:



```text

384 MB

```



The archive was inspected and confirmed to contain the expected Nextcloud directory structure.



Important files and directories found included:



```text

version.php

apps/

config/

data/

custom\_apps/

themes/

lib/

```



The archive was also checked for gzip/tar integrity.



Validation result:



```text

NEXTCLOUD BACKUP ARCHIVE VALID

```



Therefore:



```text

Nextcloud data backup: PASS

Archive integrity: PASS

Expected directory structure: PASS

```



\---



\# 11. Nextcloud Data Restore Test



A restore test was performed using a temporary Docker volume.



A temporary volume was created:



```text

udom-cloud-restore-test

```



The Nextcloud backup archive was extracted into the temporary volume.



The restored volume was inspected to verify that the expected Nextcloud structure was present.



The following components were confirmed:



```text

version.php

apps/

config/

data/

custom\_apps/

themes/

lib/

```



After the test, the temporary volume was removed:



```bash

docker volume rm udom-cloud-restore-test

```



The temporary restore volume was confirmed to no longer exist.



This test did not delete or replace the live Nextcloud data volume.



Result:



```text

Nextcloud data restore test: PASS

Temporary restore validation: PASS

Live Nextcloud data preserved: PASS

```



\---



\# 12. Database Restoration



A dedicated database restore script is provided:



```text

scripts/restore\_database.sh

```



The script accepts a compressed database backup and an optional target database.



Usage:



```bash

./scripts/restore\_database.sh /path/to/backup.sql.gz \[database\_name]

```



Example:



```bash

./scripts/restore\_database.sh ./backups/database/nextcloud\_db\_2026-09-10\_22-38-44.sql.gz nextcloud

```



The script:



1\. Checks that a backup file was supplied.

2\. Checks that the backup file exists.

3\. Determines the target database.

4\. Displays the backup and target database.

5\. Requests confirmation from the administrator.

6\. Decompresses the SQL backup.

7\. Sends the SQL data to MariaDB.

8\. Stops if any command in the pipeline fails.

9\. Reports successful completion.



The script uses:



```bash

set -e

set -o pipefail

```



This ensures that errors in the restore pipeline are not silently ignored.



\---



\# 13. Database Restore Safety



Database restoration is a potentially destructive operation.



For this reason, the restore script requires explicit administrator confirmation:



```text

Continue? (yes/no):

```



The administrator must enter:



```text

yes

```



before the restore continues.



For production deployment, database restoration should be performed during a maintenance window with Nextcloud maintenance mode enabled.



\---



\# 14. MariaDB Restore Test



A complete database restoration test was successfully performed.



The backup used was:



```text

./backups/database/nextcloud\_db\_2026-09-10\_22-38-44.sql.gz

```



The target database was:



```text

nextcloud

```



Nextcloud maintenance mode was enabled during the restoration.



The restore command completed successfully:



```text

Database restore completed successfully.

```



After restoration, the database was verified using:



```bash

docker compose exec db mariadb -u nextcloud -p nextcloud -e "SELECT DATABASE(), COUNT(\*) AS tables\_count FROM information\_schema.tables WHERE table\_schema='nextcloud';"

```



The result was:



```text

DATABASE() | tables\_count

nextcloud   | 141

```



Therefore, the database structure remained valid after restoration.



\---



\# 15. Nextcloud Application Validation After Database Restore



After the database restore, the Nextcloud application status was checked.



The result was:



```text

installed: true

version: 34.0.3.2

needsDbUpgrade: false

productname: Nextcloud

```



Maintenance mode was then disabled successfully.



The final application status was:



```text

installed: true

version: 34.0.3.2

versionstring: 34.0.3

maintenance: false

needsDbUpgrade: false

productname: Nextcloud

extendedSupport: false

```



This confirms that the restored database was compatible with the running Nextcloud application.



Final result:



```text

DATABASE RESTORE TEST: PASS

NEXTCLOUD APPLICATION VALIDATION: PASS

```



\---



\# 16. Storage Monitoring



A dedicated storage monitoring script is provided:



```text

scripts/monitor\_storage.sh

```



The script monitors:



\* Host filesystem usage

\* Docker volumes

\* Docker disk usage

\* Storage threshold





The script also contains validation to ensure that the filesystem usage percentage is correctly detected.



This is particularly important when running the scripts through Git Bash on Windows because the filesystem path can contain spaces.



\---



\# 17. Storage Monitoring Test



The storage monitoring script was successfully executed through Git Bash.





\# 18. Docker Storage Monitoring



The monitoring script also reports Docker storage consumption.



During testing, Docker reported approximately:



```text

Images:

18 total

16 active

21.18 GB size



Containers:

19 total

7 active

10.15 MB size



Local Volumes:

15 total

14 active

2.887 GB size



Build Cache:

42 entries

2.115 GB size

```



The monitoring script therefore provides visibility into both host filesystem storage and Docker-specific storage usage.



\---



\# 19. Database Monitoring



A dedicated database monitoring script is provided:



```text

scripts/monitor\_database.sh

```



The script checks whether MariaDB is accessible and operational.



The monitoring test produced:



```text

MariaDB connection: OK



Database monitoring completed successfully.

```



Result:



```text

Database monitoring: PASS

```



\---



\# 20. Backup and Restore Testing Summary



The following tests were completed:



| Test                                       | Result |

| ------------------------------------------ | ------ |

| MariaDB connectivity                       | PASS   |

| Database table verification                | PASS   |

| Database backup creation                   | PASS   |

| Database backup gzip validation            | PASS   |

| Database SQL dump validation               | PASS   |

| MariaDB database restoration               | PASS   |

| Database table count after restore         | PASS   |

| Nextcloud application status after restore | PASS   |

| Nextcloud data backup creation             | PASS   |

| Nextcloud backup archive validation        | PASS   |

| Nextcloud data restore test                | PASS   |

| Temporary restore volume cleanup           | PASS   |

| Database monitoring                        | PASS   |

| Storage monitoring                         | PASS   |

| Storage threshold warning                  | PASS   |

| Bash script syntax validation              | PASS   |

| Git whitespace/error validation            | PASS   |



\---



\# 21. Backup Directory Structure



The backup directory is organized as follows:



```text

backups/

├── database/

│   └── nextcloud\_db\_YYYY-MM-DD\_HH-MM-SS.sql.gz

│

└── nextcloud/

&#x20;   └── nextcloud\_data\_YYYY-MM-DD\_HH-MM-SS.tar.gz

```



Database and Nextcloud application data are therefore backed up separately.



This separation allows administrators to restore either layer independently when necessary.



\---



\# 22. Disaster Recovery Strategy



The infrastructure provides two primary recovery components:



```text

1\. Database recovery

2\. Nextcloud data recovery

```



A complete disaster recovery procedure should follow these steps.



\## Step 1: Stop or isolate the affected application



If required, stop the Nextcloud application or enable maintenance mode.



\## Step 2: Restore the database



Use:



```bash

./scripts/restore\_database.sh ./backups/database/nextcloud\_db\_DATE.sql.gz nextcloud

```



\## Step 3: Restore Nextcloud data



Create or use the appropriate Nextcloud data volume and extract the verified:



```text

.tar.gz

```



backup.



\## Step 4: Verify permissions



Ensure Nextcloud files are owned by the appropriate web server user inside the container.



\## Step 5: Start Nextcloud



Start the application services using Docker Compose.



\## Step 6: Validate Nextcloud



Run:



```bash

docker compose exec app php occ status

```



Verify:



```text

installed: true

maintenance: false

needsDbUpgrade: false

```



\## Step 7: Verify application functionality



Administrators should confirm:



\* User login

\* File access

\* File upload

\* File download

\* Sharing

\* Application availability

\* Database connectivity



\---



\# 23. Recommended Production Backup Strategy



The current scripts provide the foundation for production backups.



For a real UDOM production deployment, backups should be automated.



Recommended schedule:



```text

Database:

Daily



Nextcloud data:

Daily



Full disaster recovery backup:

Weekly



Long-term archive:

Monthly

```



A recommended retention policy could be:



```text

Daily backups:

Keep 7 days



Weekly backups:

Keep 4 weeks



Monthly backups:

Keep 6–12 months

```



The final retention policy should be determined by UDOM's operational and data-retention requirements.



\---



\# 24. Off-Site Backup Recommendation



The current backups are stored locally on the development machine.



This is suitable for testing but is not sufficient for production disaster recovery.



Production backups should also be copied to a separate storage location.



Possible destinations include:



```text

UDOM backup server

NAS

Secondary storage server

Institutional object storage

Offline backup media

```



The backup destination should not depend on the same physical machine as the Nextcloud deployment.



\---



\# 25. Backup Security



Backup files can contain sensitive university information.



Therefore, production backups should be protected using:



\* Restricted filesystem permissions

\* Encrypted storage

\* Secure administrator access

\* Separate backup credentials

\* Controlled backup retention

\* Access logging

\* Off-site storage protection



Database backup files should never be publicly accessible.



Backup directories should also not be exposed through the Nextcloud web server.



\---



\# 26. Storage Capacity Considerations



The current development environment has limited free disk space.



The latest monitoring test reported approximately:



```text

Total: 141 GB

Used: 139 GB

Available: 2.1 GB

Usage: 99%

```



This is a critical storage condition for a development machine.



The production UDOM deployment should therefore use storage appropriate for the expected number of:



\* Students

\* Staff

\* Courses

\* Documents

\* Shared files

\* Multimedia files

\* Backups

\* AI models

\* Application data



Production storage should also provide sufficient growth capacity.



\---



\# 27. Monitoring Recommendations for Production



For production deployment, monitoring should be expanded to include:



```text

CPU usage

RAM usage

Disk usage

Docker container health

MariaDB health

Nextcloud health

Backup success/failure

Backup age

Storage growth

Network availability

```



\---



\# 28. Script Inventory



The infrastructure scripts relevant to this implementation are:



```text

scripts/

├── backup\_database.sh

├── backup\_nextcloud.sh

├── monitor\_database.sh

├── monitor\_storage.sh

└── restore\_database.sh

```



Their responsibilities are:



| Script                | Responsibility                            |

| --------------------- | ----------------------------------------- |

| `backup\_database.sh`  | Creates compressed MariaDB backups        |

| `backup\_nextcloud.sh` | Creates compressed Nextcloud data backups |

| `monitor\_database.sh` | Checks MariaDB availability               |

| `monitor\_storage.sh`  | Monitors filesystem and Docker storage    |

| `restore\_database.sh` | Restores a MariaDB database from a backup |



\---



\# 29. Operational Commands



\## Check Nextcloud status



```bash

docker compose exec app php occ status

```



\## Enable maintenance mode



```bash

docker compose exec app php occ maintenance:mode --on

```



\## Disable maintenance mode



```bash

docker compose exec app php occ maintenance:mode --off

```



\## Check database connectivity



```bash

docker compose exec db mariadb -u nextcloud -p nextcloud -e "SELECT DATABASE();"

```



\## Check database table count



```bash

docker compose exec db mariadb -u nextcloud -p nextcloud -e "SELECT DATABASE(), COUNT(\*) AS tables\_count FROM information\_schema.tables WHERE table\_schema='nextcloud';"

```



\## Run database monitoring



```bash

bash scripts/monitor\_database.sh

```



\## Run storage monitoring



```bash

bash scripts/monitor\_storage.sh

```



\## Create database backup



```bash

bash scripts/backup\_database.sh

```



\## Create Nextcloud data backup



```bash

bash scripts/backup\_nextcloud.sh

```



\## Restore database



```bash

bash scripts/restore\_database.sh ./backups/database/nextcloud\_db\_YYYY-MM-DD\_HH-MM-SS.sql.gz nextcloud

```



\---



\# 30. Git and Backup File Management



Backup archives are intentionally excluded from version control.



The repository should contain:



```text

scripts/

docs/

docker-compose.yml

configuration files

```



but should not contain:



```text

backups/database/\*.sql.gz

backups/nextcloud/\*.tar.gz

```



This prevents large backup files and potentially sensitive application data from being committed to Git.



\---



\# 31. Implementation Status



The database, storage, backup, restoration, and monitoring implementation has been completed and tested.



Current status:



```text

Database persistence:              COMPLETE

Database backup:                   COMPLETE

Database restore:                  COMPLETE

Nextcloud data persistence:        COMPLETE

Nextcloud data backup:             COMPLETE

Nextcloud data restore testing:    COMPLETE

Database monitoring:               COMPLETE

Storage monitoring:                COMPLETE

Backup validation:                 COMPLETE

Restore validation:                COMPLETE

Disaster recovery preparation:    COMPLETE

```



\---



\# 32. Final Validation



The final Nextcloud status after database restoration was:



```text

installed: true

version: 34.0.3.2

versionstring: 34.0.3

maintenance: false

needsDbUpgrade: false

productname: Nextcloud

extendedSupport: false

```



This confirms that the Nextcloud application was successfully operational after the database restoration test.



The infrastructure therefore demonstrates successful:



```text

BACKUP

&#x20;  ↓

RESTORE

&#x20;  ↓

VALIDATION

&#x20;  ↓

APPLICATION RECOVERY

```



\---



\# 33. Conclusion



The database, storage, backup, restore, and monitoring layer of the UDOM Custom Nextcloud Deployment has been successfully implemented and validated.



The system now provides:



\* Persistent MariaDB storage

\* Persistent Nextcloud storage

\* Automated database backup capability

\* Automated Nextcloud data backup capability

\* Database restoration capability

\* Nextcloud data restoration testing

\* Database health monitoring

\* Storage monitoring

\* Backup integrity validation

\* Restore validation

\* Disaster recovery preparation



The successful MariaDB restoration test confirmed that the database can be restored from a compressed backup while preserving the Nextcloud application's operational state.



The successful Nextcloud data restore test confirmed that application storage can also be recovered independently.



The infrastructure is therefore ready to serve as the foundation for the next stages of the UDOM Custom Nextcloud Deployment, including production deployment, automated scheduling, expanded monitoring, and final UDOM branding/customization.



\---



\## Infrastructure Completion Status



\*\*STATUS: COMPLETE\*\*



\*\*Database:\*\* PASS

\*\*Storage:\*\* PASS

\*\*Backup:\*\* PASS

\*\*Restore:\*\* PASS

\*\*Monitoring:\*\* PASS

\*\*Validation:\*\* PASS



