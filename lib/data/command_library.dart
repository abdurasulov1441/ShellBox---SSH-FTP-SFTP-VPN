import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

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
  static List<LibraryCategory> get categories => [
        LibraryCategory('lib.cat.system'.tr(), HugeIcons.strokeRoundedCpu, [
          LibraryCommand('lib.c.sys1'.tr(), 'uname -a; cat /etc/os-release'),
          LibraryCommand('lib.c.sys2'.tr(), 'uptime; cat /proc/loadavg'),
          LibraryCommand('lib.c.sys3'.tr(), 'free -h'),
          LibraryCommand('lib.c.sys4'.tr(), 'df -hT; echo; lsblk'),
          LibraryCommand('lib.c.sys5'.tr(), 'du -sh /* 2>/dev/null | sort -rh | head -20'),
          LibraryCommand('lib.c.sys6'.tr(), 'ps aux --sort=-%cpu | head -15'),
          LibraryCommand('lib.c.sys7'.tr(), 'ps aux --sort=-%mem | head -15'),
          LibraryCommand('lib.c.sys8'.tr(), 'systemctl list-units --type=service --state=running --no-pager'),
          LibraryCommand('lib.c.sys9'.tr(), 'systemctl --failed --no-pager'),
          LibraryCommand('lib.c.sys10'.tr(), 'last -x | head -20'),
        ]),
        LibraryCategory('lib.cat.network'.tr(), HugeIcons.strokeRoundedInternet, [
          LibraryCommand('lib.c.net1'.tr(), 'ss -tulpn'),
          LibraryCommand('lib.c.net2'.tr(), 'ss -tan state established'),
          LibraryCommand('lib.c.net3'.tr(), 'ip -brief a; echo; ip route'),
          LibraryCommand('lib.c.net4'.tr(), 'ip neigh'),
          LibraryCommand('lib.c.net5'.tr(), 'curl -s ifconfig.me; echo'),
          LibraryCommand('lib.c.net6'.tr(), 'dig +short example.com'),
          LibraryCommand('lib.c.net7'.tr(), 'traceroute -n 1.1.1.1'),
          LibraryCommand('lib.c.net8'.tr(), 'curl -sI https://example.com'),
          LibraryCommand('lib.c.net9'.tr(), 'sudo iptables -L -n -v'),
          LibraryCommand('lib.c.net10'.tr(), 'sudo nft list ruleset'),
          LibraryCommand('lib.c.net11'.tr(), 'sudo ufw status verbose'),
        ]),
        LibraryCategory('lib.cat.audit'.tr(), HugeIcons.strokeRoundedSecurityCheck, [
          LibraryCommand('lib.c.audit1'.tr(), 'id; echo; groups'),
          LibraryCommand('lib.c.audit2'.tr(), 'sudo -l'),
          LibraryCommand('lib.c.audit3'.tr(), "grep -vE '/nologin|/false' /etc/passwd"),
          LibraryCommand('lib.c.audit4'.tr(), "sudo awk -F: '(\$2==\"\"){print \$1}' /etc/shadow"),
          LibraryCommand('lib.c.audit5'.tr(), 'find / -perm -4000 -type f 2>/dev/null'),
          LibraryCommand('lib.c.audit6'.tr(), 'find / -perm -2000 -type f 2>/dev/null'),
          LibraryCommand('lib.c.audit7'.tr(), 'find / -writable -type d 2>/dev/null | head -40'),
          LibraryCommand('lib.c.audit8'.tr(), 'getcap -r / 2>/dev/null'),
          LibraryCommand('lib.c.audit9'.tr(), 'ls -la /etc/cron*; echo; crontab -l 2>/dev/null'),
          LibraryCommand('lib.c.audit10'.tr(), 'find / -type f -mmin -30 2>/dev/null | head -40'),
          LibraryCommand('lib.c.audit11'.tr(), 'who; echo; w'),
          LibraryCommand('lib.c.audit12'.tr(), 'cat ~/.bash_history 2>/dev/null | tail -50'),
        ]),
        LibraryCategory('lib.cat.recon'.tr(), HugeIcons.strokeRoundedRadar01, [
          LibraryCommand('lib.c.recon1'.tr(), 'nmap -sV -sC -Pn TARGET'),
          LibraryCommand('lib.c.recon2'.tr(), 'nmap -T4 -F TARGET'),
          LibraryCommand('lib.c.recon3'.tr(), 'nmap -p- -T4 -Pn TARGET'),
          LibraryCommand('lib.c.recon4'.tr(), 'sudo nmap -sU --top-ports 50 TARGET'),
          LibraryCommand('lib.c.recon5'.tr(), 'nmap -sn 192.168.1.0/24'),
          LibraryCommand('lib.c.recon6'.tr(), 'nc -vz TARGET 22'),
          LibraryCommand('lib.c.recon7'.tr(), 'nc -nv TARGET 80'),
          LibraryCommand('lib.c.recon8'.tr(), 'sudo tcpdump -i any -n -c 50'),
          LibraryCommand('lib.c.recon9'.tr(),
              'echo | openssl s_client -connect TARGET:443 2>/dev/null | openssl x509 -noout -text | head -30'),
        ]),
        LibraryCategory('lib.cat.web'.tr(), HugeIcons.strokeRoundedGlobe02, [
          LibraryCommand('lib.c.web1'.tr(), 'curl -sI http://TARGET'),
          LibraryCommand('lib.c.web2'.tr(), 'curl -s -X OPTIONS http://TARGET -i'),
          LibraryCommand('lib.c.web3'.tr(), 'curl -s http://TARGET/robots.txt'),
          LibraryCommand('lib.c.web4'.tr(), 'whatweb http://TARGET'),
          LibraryCommand('lib.c.web5'.tr(), 'gobuster dir -u http://TARGET -w /usr/share/wordlists/dirb/common.txt'),
          LibraryCommand('lib.c.web6'.tr(), 'ffuf -u http://TARGET -H "Host: FUZZ.TARGET" -w wordlist.txt'),
          LibraryCommand('lib.c.web7'.tr(), 'nikto -h http://TARGET'),
          LibraryCommand('lib.c.web8'.tr(), 'wget -q -O - http://TARGET | head -40'),
        ]),
        LibraryCategory('lib.cat.docker'.tr(), HugeIcons.strokeRoundedDashboardSquare01, [
          LibraryCommand('lib.c.docker1'.tr(), 'docker ps -a'),
          LibraryCommand('lib.c.docker2'.tr(), 'docker images'),
          LibraryCommand('lib.c.docker3'.tr(), 'docker logs -f CONTAINER'),
          LibraryCommand('lib.c.docker4'.tr(), 'docker exec -it CONTAINER sh'),
          LibraryCommand('lib.c.docker5'.tr(), 'docker stats --no-stream'),
          LibraryCommand('lib.c.docker6'.tr(), 'docker system df; echo; docker system prune -f'),
          LibraryCommand('lib.c.docker7'.tr(), 'docker network ls'),
          LibraryCommand('lib.c.docker8'.tr(), 'kubectl get pods -A'),
          LibraryCommand('lib.c.docker9'.tr(), 'kubectl get nodes -o wide'),
          LibraryCommand('lib.c.docker10'.tr(), 'kubectl logs -f POD'),
        ]),
        LibraryCategory('lib.cat.logs'.tr(), HugeIcons.strokeRoundedTask01, [
          LibraryCommand('lib.c.logs1'.tr(), 'sudo journalctl -n 200 --no-pager'),
          LibraryCommand('lib.c.logs2'.tr(), 'sudo journalctl -f'),
          LibraryCommand('lib.c.logs3'.tr(), 'sudo journalctl -p err -b --no-pager'),
          LibraryCommand('lib.c.logs4'.tr(), 'sudo journalctl -u SERVICE --no-pager -n 100'),
          LibraryCommand('lib.c.logs5'.tr(), 'sudo grep -i "failed password" /var/log/auth.log | tail -40'),
          LibraryCommand('lib.c.logs6'.tr(), 'sudo dmesg -T | tail -40'),
          LibraryCommand('lib.c.logs7'.tr(), 'systemd-analyze; systemd-analyze blame | head -15'),
        ]),
        LibraryCategory('lib.cat.nmap'.tr(), HugeIcons.strokeRoundedTarget02, [
          LibraryCommand('lib.c.nmap1'.tr(), 'nmap -sn 192.168.1.0/24'),
          LibraryCommand('lib.c.nmap2'.tr(), 'sudo nmap -O TARGET'),
          LibraryCommand('lib.c.nmap3'.tr(), 'nmap -A -T4 TARGET'),
          LibraryCommand('lib.c.nmap4'.tr(), 'nmap --script vuln TARGET'),
          LibraryCommand('lib.c.nmap5'.tr(), 'nmap -sC -sV TARGET'),
          LibraryCommand('lib.c.nmap6'.tr(), 'nmap --top-ports 1000 -T4 TARGET'),
          LibraryCommand('lib.c.nmap7'.tr(), 'nmap -A -oN scan.txt TARGET'),
          LibraryCommand('lib.c.nmap8'.tr(), 'sudo nmap -sU -F TARGET'),
          LibraryCommand('lib.c.nmap9'.tr(), 'sudo nmap -sS -Pn -T4 TARGET'),
          LibraryCommand('lib.c.nmap10'.tr(), 'nmap --script http-enum -p80,443 TARGET'),
          LibraryCommand('lib.c.nmap11'.tr(), 'nmap --script ssl-enum-ciphers -p443 TARGET'),
          LibraryCommand('lib.c.nmap12'.tr(), 'sudo nmap -sS -p- --min-rate 2000 -Pn TARGET'),
        ]),
        LibraryCategory('lib.cat.sniff'.tr(), HugeIcons.strokeRoundedActivity01, [
          LibraryCommand('lib.c.sniff1'.tr(), 'tshark -D'),
          LibraryCommand('lib.c.sniff2'.tr(), 'sudo tshark -i any -c 100'),
          LibraryCommand('lib.c.sniff3'.tr(),
              'sudo tshark -i any -Y "http.request" -T fields -e http.host -e http.request.uri'),
          LibraryCommand('lib.c.sniff4'.tr(), 'sudo tshark -i any -Y "dns" -T fields -e dns.qry.name'),
          LibraryCommand('lib.c.sniff5'.tr(), 'sudo tshark -i any -w capture.pcap'),
          LibraryCommand('lib.c.sniff6'.tr(), 'tshark -r capture.pcap'),
          LibraryCommand('lib.c.sniff7'.tr(), 'sudo tshark -i any -Y "http.request.method==POST"'),
          LibraryCommand('lib.c.sniff8'.tr(), 'sudo tcpdump -i any host TARGET -n'),
          LibraryCommand('lib.c.sniff9'.tr(), 'sudo tcpdump -i any port 443 -n -c 50'),
          LibraryCommand('lib.c.sniff10'.tr(), 'capinfos capture.pcap'),
          LibraryCommand('lib.c.sniff11'.tr(), 'sudo tcpdump -i any -w dump.pcap -C 10 -W 5'),
        ]),
        LibraryCategory('lib.cat.ipscan'.tr(), HugeIcons.strokeRoundedGlobalSearch, [
          LibraryCommand('lib.c.ipscan1'.tr(), 'sudo arp-scan --localnet'),
          LibraryCommand('lib.c.ipscan2'.tr(), 'sudo netdiscover -r 192.168.1.0/24'),
          LibraryCommand('lib.c.ipscan3'.tr(), 'fping -a -g 192.168.1.0/24 2>/dev/null'),
          LibraryCommand('lib.c.ipscan4'.tr(), 'sudo masscan 192.168.1.0/24 -p80,443 --rate 1000'),
          LibraryCommand('lib.c.ipscan5'.tr(),
              r'for i in $(seq 1 254); do ping -c1 -W1 192.168.1.$i >/dev/null 2>&1 && echo 192.168.1.$i up; done'),
          LibraryCommand('lib.c.ipscan6'.tr(), 'avahi-browse -alt'),
          LibraryCommand('lib.c.ipscan7'.tr(), 'sudo nbtscan 192.168.1.0/24'),
          LibraryCommand('lib.c.ipscan8'.tr(), 'ip neigh show'),
          LibraryCommand('lib.c.ipscan9'.tr(), 'arp -a'),
        ]),
      ];
}
