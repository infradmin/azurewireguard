#cloud-config
write_files:
  - content: |
      localip=${localip}
      remoteip=${remoteip}
      port=${port}
      dbpath=${dbpath}
      region=${region}
      azregion=${azregion}
    path: "/root/wg.ini"
  - content: |
      ${username}
    path: "/root/.ssh/username"
  - content: |
      ${id_rsa}
    path: "/root/.ssh/id_rsa"
    permissions: '600'
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
      table {margin:auto; border-spacing:0 2em;}
      td {background-color:#323232;height:200px;width:200px;}
      </style>
      </head>
      <body>
      <br><h1><span style="text-transform:uppercase;">${region}</span> WireGuard clients</h1>
      <table>
      </table>
      </body>
      <script>
      let table = document.querySelector("table");
      for (let i = 10; i < 100; i++) {
      let row = table.insertRow();
      row.innerHTML = '<td><h3>Client '+i+'</h3><a href="clients/conf/client'+i+'.conf">Download conf</a></td><td><img src="clients/qr/client'+i+'.png" alt="QR"></td>';
      }
      </script>
      </html>
    path: /var/www/html/index.html
  - content: |
      #!/bin/bash
      . $1/wg.ini
      read username < /root/.ssh/username
      umask 033
      ssh-keygen -R $remoteip
      if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa $username@$remoteip "[ -d $dbpath/$region ]"
      then
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa $username@$remoteip "touch $dbpath/$region"
        rsync -az -e "ssh -i /root/.ssh/id_rsa" $username@$remoteip:$dbpath/$region/ $dbpath
      else
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa $username@$remoteip "mkdir -p $dbpath/$region"
      fi
      [[ -f $dbpath/server/keys/privatekey ]] || { [[ -f /etc/wireguard/wg0.conf ]] && sed -n "s/PrivateKey = //w $dbpath/server/keys/privatekey" /etc/wireguard/wg0.conf; wg pubkey > $dbpath/server/keys/publickey < $dbpath/server/keys/privatekey || rm $dbpath/server/keys/privatekey; }
      [[ -f $dbpath/server/keys/privatekey ]] || { [[ -f $dbpath/server/wg0.conf ]] && sed -n "s/PrivateKey = //w $dbpath/server/keys/privatekey" $dbpath/server/wg0.conf; wg pubkey > $dbpath/server/keys/publickey < $dbpath/server/keys/privatekey || rm $dbpath/server/keys/privatekey; }
      [[ -f $dbpath/server/keys/privatekey ]] || { wg genkey | tee $dbpath/server/keys/privatekey | wg pubkey > $dbpath/server/keys/publickey; rm $dbpath/server/wg0.conf $dbpath/clients/conf/*; }
      grep -q $(wg pubkey < $dbpath/server/keys/privatekey) $dbpath/server/keys/publickey || rm $dbpath/server/keys/publickey
      [[ -f $dbpath/server/keys/publickey ]] || { wg pubkey > $dbpath/server/keys/publickey < $dbpath/server/keys/privatekey; }
      for i in {10..99}
      do
        [[ -f $dbpath/clients/keys/client$(echo $i).privatekey ]] || { [[ -f $dbpath/clients/conf/client$(echo $i).conf ]] && sed -n "s/PrivateKey = //w $dbpath/clients/keys/client$(echo $i).privatekey" $dbpath/clients/conf/client$(echo $i).conf; wg pubkey > $dbpath/clients/keys/client$(echo $i).publickey < $dbpath/clients/keys/client$(echo $i).privatekey || rm $dbpath/clients/keys/client$(echo $i).privatekey; }
        [[ -f $dbpath/clients/keys/client$(echo $i).privatekey ]] || { wg genkey | tee $dbpath/clients/keys/client$(echo $i).privatekey | wg pubkey > $dbpath/clients/keys/client$(echo $i).publickey;rm -f $dbpath/server/wg0.conf $dbpath/clients/conf/client$(echo $i).conf $dbpath/clients/qr/client$(echo $i).png; }
        grep -q $(wg pubkey < $dbpath/clients/keys/client$(echo $i).privatekey) $dbpath/clients/keys/client$(echo $i).publickey || rm $dbpath/clients/keys/client$(echo $i).publickey
        [[ -f $dbpath/clients/keys/client$(echo $i).publickey ]] || { wg pubkey > $dbpath/clients/keys/publickey < $dbpath/clients/keys/privatekey; }
      done
      cmp $dbpath/wg.ini $dbpath/wg.cmp || rm $dbpath/server/wg0.conf
      grep -qFf $dbpath/server/keys/privatekey $dbpath/server/wg0.conf || rm $dbpath/server/wg0.conf $dbpath/clients/conf/*
      for i in {10..99}
      do
        grep -qFf $dbpath/server/keys/publickey $dbpath/clients/conf/client$(echo $i).conf || rm $dbpath/clients/conf/client$(echo $i).conf
        grep -qFf $dbpath/clients/keys/client$(echo $i).privatekey $dbpath/clients/conf/client$(echo $i).conf || rm $dbpath/clients/conf/client$(echo $i).conf
        grep -qFf $dbpath/clients/keys/client$(echo $i).publickey $dbpath/server/wg0.conf || rm $dbpath/server/wg0.conf
      done
      if [[ ! -f $dbpath/server/wg0.conf ]]
      then
        echo -e "[Interface]\nPrivateKey = $(<$dbpath/server/keys/privatekey)\nAddress = 172.27.1.1/24\nListenPort = $port\nPostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE\nPostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE" > $dbpath/server/wg0.conf
        for i in {10..99}; do echo -e "\n[Peer]\n# Name = Client$(echo $i)\nPublicKey = $(<$dbpath/clients/keys/client$(echo $i).publickey)\nAllowedIPs = 172.27.1.$(echo $i)/32" >> $dbpath/server/wg0.conf; done
      fi
      cmp -s $dbpath/server/wg0.conf etc/wireguard/wg0.conf || { cp -f $dbpath/server/wg0.conf /etc/wireguard/; sudo service wg-quick@wg0 restart; }
      for i in {10..99}
      do
        [[ -f $dbpath/clients/conf/client$(echo $i).conf ]] || { echo -e "[Interface]\nPrivateKey = $(<$dbpath/clients/keys/client$(echo $i).privatekey)\nAddress = 172.27.1.$(echo $i)/24\nDNS = 1.1.1.1\n\n[Peer]\nEndpoint = $localip:$port\nPublicKey = $(<$dbpath/server/keys/publickey)\nAllowedIPs = 0.0.0.0/0" > $dbpath/clients/conf/client$(echo $i).conf; rm $dbpath/clients/qr/client$(echo $i).png; }
        [[ -f $dbpath/clients/qr/client$(echo $i).png ]] || { qrencode -t png -r $dbpath/clients/conf/client$(echo $i).conf -o $dbpath/clients/qr/client$(echo $i).png; }
      done
      if cmp $dbpath/wg.ini $dbpath/wg.cmp
      then
        rsync -az -e "ssh -i /root/.ssh/id_rsa" --exclude=wg.ini --ignore-existing $dbpath/ $username@$remoteip:$dbpath/$region
      else
        rsync -az -e "ssh -i /root/.ssh/id_rsa" --exclude=wg.ini $dbpath/ $username@$remoteip:$dbpath/$region
      fi
      rsync -az -e "ssh -i /root/.ssh/id_rsa" $dbpath/wg.ini $username@$remoteip:$dbpath/$region/wg.cmp
      ssh -o BatchMode=yes -i /root/.ssh/id_rsa $username@$remoteip "echo $(date) > $dbpath/$region"
      cp -f $dbpath/wg.ini $dbpath/wg.cmp
    path: ${scriptpath}/syncwg.sh
    permissions: '755'
package_update: true
package_upgrade: true
packages:
  - wireguard
  - qrencode
  - nginx
  - mc
runcmd:
  - sed -i '/net.ipv4.ip_forward/s/^#//g' /etc/sysctl.conf
  - sysctl -p
  - mkdir -p ${dbpath}/server/keys
  - mkdir -p ${dbpath}/clients/keys
  - mkdir ${dbpath}/clients/conf
  - mkdir ${dbpath}/clients/qr
  - mv /root/wg.ini ${dbpath}/
  - bash ${scriptpath}//syncwg.sh ${dbpath}
  - systemctl enable wg-quick@wg0
  - systemctl start wg-quick@wg0
  - (crontab -l 2>/dev/null; echo "MAILTO=''") | crontab -
  - (crontab -l 2>/dev/null; echo "$((${index}%15))-$((${index}%2+58))/15 * * * * bash ${scriptpath}/syncwg.sh ${dbpath}") | crontab -
  - (crontab -l 2>/dev/null; echo "0-58/2 * * * * curl http://20.216.0.247 > /dev/null 2>&1 && { systemctl is-active nginx && sudo systemctl stop nginx; true; } || { systemctl is-active nginx || sudo systemctl start nginx; }") | crontab -
  - (crontab -l 2>/dev/null; echo "1-59/2 * * * * service wg-quick@wg0 status > /dev/null || sudo service wg-quick@wg0 restart") | crontab -
  - rm /var/www/html/index.nginx-debian.html
  - mkdir /var/www/html/clients
  - echo -n '${username}:' > /etc/nginx/.htpasswd
  - openssl passwd -apr1 '${password}' >> /etc/nginx/.htpasswd
  - nginx -s reload
  - ln -s ${dbpath}/clients/conf /var/www/html/clients/conf
  - ln -s ${dbpath}/clients/qr /var/www/html/clients/qr
