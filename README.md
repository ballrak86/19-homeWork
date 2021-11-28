## Описание файлов в директории
logFileFull.log - полный лог выполнения  

Vagrant_folder - все что понадобится для поднятия ВМ и краткое описание файлов в ней  
Vagrantfile - вагрант файл  
knock.sh - скрипт для Port Knocking

## Как выглядит сеть и запрос curl
![net](/net.JPG "Сеть дз")

## Описание как запустить виртуальную машину (кратко)
Большая часть ВМ закомментированы, оставленны только нужные inetRouter, inetRouter2, centralRouter, centralServer. Ничего не мешает поднять и оставшиеся ВМ, но на результат работы они не повлияют.
Поднять ВМ и подключиться к ВМ centralRouter
```
vagrant up
vagrant ssh centralRouter
```
Выполнить команды ниже, чтобы подключиться по ssh к inetRouter. Пароль vagrant
```
/vagrant/knock.sh 192.168.255.1 8881 7777 9991
ssh vagrant@192.168.255.1
```
На хосте выполняем curl который пройдет через ВМ inetRouter2
```
curl http://192.168.11.150:8080
```

## VagrantFile только важное
На ВМ inetRouter настраиваем iptables чтобы использовать Port Knocking. Так же открываем доступ по паролю.
```
        case boxname.to_s
        when "inetRouter"
          box.vm.provision "shell", run: "always", inline: <<-SHELL
            echo 1 > /proc/sys/net/ipv4/ip_forward
            iptables -t nat -A POSTROUTING ! -d 192.168.0.0/16 -o eth0 -j MASQUERADE
            iptables -N TRAFFIC
            iptables -N SSH-INPUT
            iptables -N SSH-INPUTTWO
            iptables -t filter -A INPUT -j TRAFFIC
            iptables -t filter -A TRAFFIC -p icmp --icmp-type any -j ACCEPT
            iptables -t filter -A TRAFFIC -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 22 -m recent --rcheck --seconds 30 --name SSH2 -j ACCEPT
            iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH2 --remove -j DROP
            iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 9991 -m recent --rcheck --name SSH1 -j SSH-INPUTTWO
            iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH1 --remove -j DROP
            iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 7777 -m recent --rcheck --name SSH0 -j SSH-INPUT
            iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp -m recent --name SSH0 --remove -j DROP
            iptables -t filter -A TRAFFIC -m state --state NEW -m tcp -p tcp --dport 8881 -m recent --name SSH0 --set -j DROP
            iptables -t filter -A SSH-INPUT -m recent --name SSH1 --set -j DROP
            iptables -t filter -A SSH-INPUTTWO -m recent --name SSH2 --set -j DROP
            iptables -t filter -A TRAFFIC -j DROP
            ip r add 192.168.0.0/24 via 192.168.255.2
            ip r add 192.168.1.0/24 via 192.168.255.2
            ip r add 192.168.2.0/24 via 192.168.255.2
            sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
            systemctl restart sshd
            SHELL
```
На ВМ inetRouter2 настраиваем проброс порта. Любой входящий трафик на порт 8080, в PREROUTING меняем адрес назаначения 192.168.0.2:80. А в POSTROUTING меняем адрес отправителя.
```
        when "inetRouter2"
          box.vm.provision "shell", run: "always", inline: <<-SHELL
            echo 1 > /proc/sys/net/ipv4/ip_forward
            iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
            iptables -t nat -I POSTROUTING -p tcp --dst 192.168.0.2 --dport 80 -j SNAT --to 192.168.254.1
            ip r add 192.168.0.2/32 via 192.168.254.2
            SHELL
```
## knock.sh
Вызов скрипта выглядит так
```
/vagrant/knock.sh 192.168.255.1 8881 7777 9991
```
В цикле передаем порты и стучимся через nmap на указаный хост
```
#!/bin/bash
HOST=$1
shift
for ARG in "$@"
do
  nmap -Pn --max-retries 0 -p $ARG $HOST
done
```

📚Домашнее задание/проектная работа разработано(-на) для курса ["Administrator Linux. Professional"](https://otus.ru/lessons/linux-professional/)