import 'package:flutter/material.dart';

class LibraryCommand {
  const LibraryCommand(this.name, this.command);

  final String name;
  final String command;
}

class LibraryCategory {
  const LibraryCategory(this.title, this.icon, this.commands);

  final String title;
  final IconData icon;
  final List<LibraryCommand> commands;
}

class CommandLibrary {
  static const List<LibraryCategory> categories = [
    LibraryCategory('Система', Icons.memory_rounded, [
      LibraryCommand('Система и ядро', 'uname -a; cat /etc/os-release'),
      LibraryCommand('Аптайм и нагрузка', 'uptime; cat /proc/loadavg'),
      LibraryCommand('Использование памяти', 'free -h'),
      LibraryCommand('Диски', 'df -hT; echo; lsblk'),
      LibraryCommand('Крупнейшие папки', 'du -sh /* 2>/dev/null | sort -rh | head -20'),
      LibraryCommand('Топ процессов по CPU', 'ps aux --sort=-%cpu | head -15'),
      LibraryCommand('Топ процессов по памяти', 'ps aux --sort=-%mem | head -15'),
      LibraryCommand('Активные службы', 'systemctl list-units --type=service --state=running --no-pager'),
      LibraryCommand('Службы с ошибками', 'systemctl --failed --no-pager'),
      LibraryCommand('Последние входы', 'last -x | head -20'),
    ]),
    LibraryCategory('Сеть', Icons.lan_rounded, [
      LibraryCommand('Слушающие порты', 'ss -tulpn'),
      LibraryCommand('Все соединения', 'ss -tan state established'),
      LibraryCommand('Адреса и интерфейсы', 'ip -brief a; echo; ip route'),
      LibraryCommand('Таблица ARP', 'ip neigh'),
      LibraryCommand('Внешний IP', 'curl -s ifconfig.me; echo'),
      LibraryCommand('DNS-запрос', 'dig +short example.com'),
      LibraryCommand('Трассировка', 'traceroute -n 1.1.1.1'),
      LibraryCommand('Заголовки ответа', 'curl -sI https://example.com'),
      LibraryCommand('Правила iptables', 'sudo iptables -L -n -v'),
      LibraryCommand('Правила nftables', 'sudo nft list ruleset'),
      LibraryCommand('Статус UFW', 'sudo ufw status verbose'),
    ]),
    LibraryCategory('Аудит и права', Icons.verified_user_rounded, [
      LibraryCommand('Кто я и группы', 'id; echo; groups'),
      LibraryCommand('Права sudo', 'sudo -l'),
      LibraryCommand('Пользователи с оболочкой', "grep -vE '/nologin|/false' /etc/passwd"),
      LibraryCommand('Пустые пароли', "sudo awk -F: '(\$2==\"\"){print \$1}' /etc/shadow"),
      LibraryCommand('SUID-файлы', 'find / -perm -4000 -type f 2>/dev/null'),
      LibraryCommand('SGID-файлы', 'find / -perm -2000 -type f 2>/dev/null'),
      LibraryCommand('Папки, доступные на запись', 'find / -writable -type d 2>/dev/null | head -40'),
      LibraryCommand('Файлы с capabilities', 'getcap -r / 2>/dev/null'),
      LibraryCommand('Задания cron', 'ls -la /etc/cron*; echo; crontab -l 2>/dev/null'),
      LibraryCommand('Недавно изменённые файлы', 'find / -type f -mmin -30 2>/dev/null | head -40'),
      LibraryCommand('Активные сессии', 'who; echo; w'),
      LibraryCommand('История bash', 'cat ~/.bash_history 2>/dev/null | tail -50'),
    ]),
    LibraryCategory('Разведка', Icons.radar_rounded, [
      LibraryCommand('Версии и баннеры', 'nmap -sV -sC -Pn TARGET'),
      LibraryCommand('Быстрое сканирование', 'nmap -T4 -F TARGET'),
      LibraryCommand('Все TCP-порты', 'nmap -p- -T4 -Pn TARGET'),
      LibraryCommand('UDP-топ', 'sudo nmap -sU --top-ports 50 TARGET'),
      LibraryCommand('Пинг-свип подсети', 'nmap -sn 192.168.1.0/24'),
      LibraryCommand('Проверка порта (nc)', 'nc -vz TARGET 22'),
      LibraryCommand('Баннер сервиса', 'nc -nv TARGET 80'),
      LibraryCommand('Перехват трафика', 'sudo tcpdump -i any -n -c 50'),
      LibraryCommand('TLS-сертификат',
          'echo | openssl s_client -connect TARGET:443 2>/dev/null | openssl x509 -noout -text | head -30'),
    ]),
    LibraryCategory('Веб', Icons.public_rounded, [
      LibraryCommand('HTTP-заголовки', 'curl -sI http://TARGET'),
      LibraryCommand('Разрешённые методы', 'curl -s -X OPTIONS http://TARGET -i'),
      LibraryCommand('robots.txt', 'curl -s http://TARGET/robots.txt'),
      LibraryCommand('Определить веб-стек', 'whatweb http://TARGET'),
      LibraryCommand('Перебор директорий', 'gobuster dir -u http://TARGET -w /usr/share/wordlists/dirb/common.txt'),
      LibraryCommand('Перебор поддоменов', 'ffuf -u http://TARGET -H "Host: FUZZ.TARGET" -w wordlist.txt'),
      LibraryCommand('Nikto-скан', 'nikto -h http://TARGET'),
      LibraryCommand('Скачать страницу', 'wget -q -O - http://TARGET | head -40'),
    ]),
    LibraryCategory('Docker / K8s', Icons.widgets_rounded, [
      LibraryCommand('Контейнеры', 'docker ps -a'),
      LibraryCommand('Образы', 'docker images'),
      LibraryCommand('Логи контейнера', 'docker logs -f CONTAINER'),
      LibraryCommand('Войти в контейнер', 'docker exec -it CONTAINER sh'),
      LibraryCommand('Ресурсы контейнеров', 'docker stats --no-stream'),
      LibraryCommand('Очистка системы', 'docker system df; echo; docker system prune -f'),
      LibraryCommand('Сети Docker', 'docker network ls'),
      LibraryCommand('Поды kubectl', 'kubectl get pods -A'),
      LibraryCommand('Узлы кластера', 'kubectl get nodes -o wide'),
      LibraryCommand('Логи пода', 'kubectl logs -f POD'),
    ]),
    LibraryCategory('Логи', Icons.article_rounded, [
      LibraryCommand('Системный журнал', 'sudo journalctl -n 200 --no-pager'),
      LibraryCommand('Журнал в реальном времени', 'sudo journalctl -f'),
      LibraryCommand('Ошибки с загрузки', 'sudo journalctl -p err -b --no-pager'),
      LibraryCommand('Журнал службы', 'sudo journalctl -u SERVICE --no-pager -n 100'),
      LibraryCommand('Неудачные входы', 'sudo grep -i "failed password" /var/log/auth.log | tail -40'),
      LibraryCommand('Сообщения ядра', 'sudo dmesg -T | tail -40'),
      LibraryCommand('Время загрузки', 'systemd-analyze; systemd-analyze blame | head -15'),
    ]),
  ];
}
