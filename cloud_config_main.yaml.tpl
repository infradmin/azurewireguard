#cloud-config
write_files:
  - content: |
      server {
        listen 80 default_server;
        root /var/www/html;
        index index.html index.htm;
        server_name localhost;
        location / {
        try_files $uri $uri/ =404;
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/.htpasswd;
        }
      }
    path: /etc/nginx/sites-enabled/default
  - content: |
      <!DOCTYPE html>
      <html>
      <head>
      <title>WireGuard clients</title>
      <style>
      body {margin:0 auto; height:100%; background-color:black; font-family:Tahoma, Verdana, Arial, sans-serif; text-align:center; vertical-align:middle; color:white;}
      select {width:100px;}
      table {margin:auto; border-spacing:0 2em;}
      td {background-color:#323232;height:200px;width:200px;}
      </style>
      </head>
      <body>
      <br><h1>WireGuard clients</h1>
      <select onchange="clChange(this);"><option>select a client</option></select>
      <table></table>
      </body>
      <script>
      regionList=[];
      azureList=[];
      clSelect=document.querySelector("select");
      clTable=document.querySelector("table");
      if (regionList.length>0) {for (let i=10; i<100; i++) {
      clOption=document.createElement("option");
      clOption.value=i;
      clOption.text='client'+i;
      clSelect.appendChild(clOption);
      }}
      function clChange(selectObj) {
      let clNo=selectObj.options[selectObj.selectedIndex].value;
      for (let i=clTable.rows.length; i>0; i--) {clTable.deleteRow(0);}
      if (clNo>0) {for (let i=0; i<regionList.length; i++) {(clTable.insertRow()).innerHTML = '<td><h2>Client '+clNo+'</h2><h3>'+azureList[i]+'</h3><a href="clients/'+regionList[i]+'/conf/client'+clNo+'.conf" download="client'+clNo+azureList[i]+'.conf">Download conf</a></td><td><img src="clients/'+regionList[i]+'/qr/client'+clNo+'.png" alt="QR"></td>';}}
      }
      </script>
      </html>
    path: /var/www/html/index.html
  - content: |
      #!/bin/bash
      cd $1
      find * -maxdepth 0 -mtime +90 -type d -delete
      find * -maxdepth 0 -mmin -30 -type d > active.new
      cmp active.new active.old && rm active.new || {
        for i in $(cat active.new)
        do
          reg=$reg'", "'$i
          azr=$azr'", "'$(sed -n 's/azregion=//p' $1/$i/wg.cmp)
          [[ -d /var/www/html/clients/$i ]] || mkdir -p /var/www/html/clients/$i
          [[ -L /var/www/html/clients/$i/conf ]] || ln -s $1/$i/clients/conf /var/www/html/clients/$i/conf
          [[ -L /var/www/html/clients/$i/qr ]] || ln -s $1/$i/clients/qr /var/www/html/clients/$i/qr
        done
        reg=$(echo $reg\" | cut -c 4-)
        azr=$(echo $azr\" | cut -c 4-)
        sed -i "/regionList=/c\regionList=[$reg];" /var/www/html/index.html
        sed -i "/azureList=/c\azureList=[$azr];" /var/www/html/index.html
        for i in $(ls /var/www/html/clients/)
        do
        echo $reg | grep -q $i || rm -rf /var/www/html/clients/$i
        done
        mv -f active.{new,old}
      }
    path: ${scriptpath}/updatehtml.sh
    permissions: '755'
package_update: true
package_upgrade: true
packages:
  - nginx
  - mc
runcmd:
  - mkdir -m 777 -p ${dbpath}
  - rm /var/www/html/index.nginx-debian.html
  - echo -n '${username}:' > /etc/nginx/.htpasswd
  - openssl passwd -apr1 '${password}' >> /etc/nginx/.htpasswd
  - nginx -s reload
  - (crontab -l 2>/dev/null; echo "MAILTO=''") | crontab -
  - (crontab -l 2>/dev/null; echo "*/3 * * * * bash ${scriptpath}/updatehtml.sh ${dbpath}") | crontab -
  - (crontab -l 2>/dev/null; echo "* * * * * systemctl is-active --quiet nginx || sudo systemctl start nginx") | crontab -
