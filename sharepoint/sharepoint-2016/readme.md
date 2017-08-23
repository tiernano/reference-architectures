# Readme for SharePoint 2016 Reference Architecture

The following readme covers how to run scripts to setup the final part of SQL Always-On.




## Step 1 : Set up SQL2 VM for Always-On with Availability Groups
1. Login into the JumpBox "ra-sp2016-jb-vm1".
   * User : \testuser - note the jumpBox doesn't belong to any domain
   * Password: AweS0me@PW
2. Login into the SQL2 VM  "sql2.contoso.local"
   * User: contoso\testuser - the SQL VM are in the domain contoso.local
3. Copy over the PowerShell script  from ./script/SetupAvailabilityGroup_SQL2.ps1 to a directory on SQL2 VM
4. Open an PowerShell window with Adminstrator priviledge 
5. Navigate to the location of the PowerShell script
6. Run the script.  It will take several minutes while it backup and restores all the databases to SQL1
7. Exit SQL2 VM

## Step 2: Setup SQL1 VM by setting up Logins for Always-On
1. Login into JumpBox "ra-sp2016-jb-vm1"
2. Login into the SQL1 VM  "sql1.contoso.local"
   * User: contoso\testuser - the SQL VM are in the domain contoso.local
3. Open up the Microsoft SQL Server Mangement Studio 
4. Open a new SQL query in Microsoft SQL Server Management Studio
5. Open SQL script from github ./script/SetupLogins_SQL1.tsql.txt in NotePad or a text editor
6. Copy SQL script
7. Paste SQL script into new SQL query window in Microsoft SQL Server Management Studio
8. Execute SQL script 
9. Exit SQL1 VM


At this point SQL Always-On fail-over will be working. 