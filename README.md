🚀 Kiloview Cube R1 FTP Easy Setup & Cleanup
Use this command to install or remove an FTP server configured for Kiloview Cube R1. It will automatically create the user, set up the directories, configure passive ports, and export ready-to-use FTP parameters.



bash -i <(curl -sSL https://raw.githubusercontent.com/simonemessina92/FTP-server-CubeR1/main/kiloview_ftp_easysetup_or_cleanup_v3.sh)



🟢 Works on Ubuntu 20.04/22.04 – cloud or local VPS

📄 Saves configuration summary in /home/[user]/ftp/ftp_config_summary.txt

❌ Includes full cleanup mode


You can also use this updated version with NGNIX cloud easy download using the following line :

bash -i <(curl -sSL https://raw.githubusercontent.com/simonemessina92/FTP-server-CubeR1/main/FTP%2Bnginx-cloud)
