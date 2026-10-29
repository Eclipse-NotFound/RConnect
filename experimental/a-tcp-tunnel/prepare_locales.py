from pathlib import Path
import json
RC=Path(__file__).resolve().parents[2];ROOT=RC/'build/github-a-release'
p=ROOT/'locales/messages.json';d=json.loads(p.read_text('utf8'))
codes=['zh','tw','en','ru','ua','pl','de','es','jp']
rows=[[
'请填写域名或 IP，可附端口；不支持网页链接。',
'請填寫網域或 IP，可附連接埠；不支援網頁連結。',
'Enter a hostname or IP, optionally with a port. Web links are not supported.',
'Введите имя узла или IP, при необходимости с портом. Веб-ссылки не поддерживаются.',
'Введіть домен або IP, за потреби з портом. Вебпосилання не підтримуються.',
'Wpisz nazwę hosta lub IP, opcjonalnie z portem. Linki WWW nie są obsługiwane.',
'Hostnamen oder IP eingeben, optional mit Port. Weblinks werden nicht unterstützt.',
'Introduce un dominio o IP, con puerto si hace falta. No se admiten enlaces web.',
'ホスト名またはIPを入力してください。ポートも指定できます。Webリンクには対応していません。'],[
'TCP 穿透：宿主填写本地端口；隧道转发到 127.0.0.1 的此端口。加入侧填写穿透域名和外部端口，也可直接粘贴域名:端口。',
'TCP 穿透：主機填寫本機連接埠；通道轉發至 127.0.0.1 的此連接埠。加入方填寫通道網域和外部連接埠，也可直接貼上網域:連接埠。',
'TCP tunnel: the host uses the local port; forward to that port on 127.0.0.1. The guest uses the tunnel hostname and external port. You can paste hostname:port directly.',
'TCP-туннель: ведущий указывает локальный порт; туннель направляется на этот порт 127.0.0.1. Гость вводит адрес туннеля и внешний порт. Можно вставить адрес:порт целиком.',
'TCP-тунель: хост задає локальний порт; тунель пересилає на цей порт 127.0.0.1. Гість вводить домен тунелю й зовнішній порт. Можна вставити домен:порт разом.',
'Tunel TCP: gospodarz podaje port lokalny; tunel przekierowuje na ten port w 127.0.0.1. Gość wpisuje adres tunelu i port zewnętrzny. Możesz wkleić adres:port.',
'TCP-Tunnel: Der Host nutzt den lokalen Port; der Tunnel leitet auf diesen Port an 127.0.0.1 weiter. Der Gast nutzt Tunneladresse und externen Port. Adresse:Port lässt sich direkt einfügen.',
'Túnel TCP: el anfitrión usa el puerto local; el túnel reenvía a ese puerto en 127.0.0.1. El invitado usa el dominio del túnel y el puerto externo. Puedes pegar dominio:puerto.',
'TCPトンネル：ホストはローカルポートを設定し、トンネルを127.0.0.1の同じポートに転送します。参加側はトンネルのホスト名と外部ポートを入力します。ホスト名:ポートの貼り付けも可能です。']]
for row in rows:d[row[0]]=dict(zip(codes,row))
key='connect failed (check ip/port)'
values=['连接失败。请检查地址、连接端口和 TCP 隧道是否启动。','連線失敗。請檢查位址、連接埠和 TCP 通道是否啟動。','Connection failed. Check the address, destination port and TCP tunnel.','Сбой соединения. Проверьте адрес, порт назначения и TCP-туннель.','Помилка з’єднання. Перевірте адресу, порт призначення й TCP-тунель.','Błąd połączenia. Sprawdź adres, port docelowy i tunel TCP.','Verbindung fehlgeschlagen. Adresse, Zielport und TCP-Tunnel prüfen.','Error de conexión. Revisa la dirección, el puerto de destino y el túnel TCP.','接続に失敗しました。アドレス、接続先ポート、TCPトンネルを確認してください。']
d[key]=dict(zip(codes,values))
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
p=ROOT/'src/RConnectMod.as';s=p.read_text('utf8');assert '0.2.24-animfix3-l10n' in s
p.write_text(s.replace('0.2.24-animfix3-l10n','0.2.24-tcp1'),encoding='utf8')
