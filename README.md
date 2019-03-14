# dht-mqtt-Lua
ESP8266-01 mit DHT sensor überträgt die Daten an MQTT Broker.

-----     Generelle NodeMCU Informationen     -----

NodeMCU mappt die ESP Pins:  PIN MAP:   GPIO0->PIN 3    GPIO2->PIN 4
DHT Data Pin MUSS GPIO2 sein, weil auch DHT schläft mit GND auf Data Pin! Dies führt zu FlashMode nach einem aufwachen des ESP´s

-----     Firmware.bin     -----

Die Firmware.bin wurde mithilfe von  https://nodemcu-build.com/  erstellt.
Es sind mehr Bibiolotheken vorhanden als momentan verwendet.

Modules in Firmware.bin: adc,dht,enduser_setup,file,gpio,http,mqtt,net,node,tmr,uart,wifi

Unbedingt notwendig sind die zusätzlichen Bibilotheken:  "adc, MQTT, enduser, DHT, file"


-----     init.lua     -----

Diese init.lua unterstützt einen Debug Modus. Entweder direkt im Code aktvierbar mit Debug="ON".
Oder eine Datei mit dem Namen   debug   befindet sich im Speicher des ESP8266.

Es ist ratsam nach dem ersten Flashen den Chip an stabile 3,3V zu hängen, denn nach erfolgreicher Verbindung wird überprüft,
ob eine Kalibration der Spannung notwendig ist.

Nach dem Flashen/ersten start des ESP´s muss die Wlan Verbindung eingerichtet werden.
Dazu wird ein AccessPoint gestartet mit dem Namen der in der Variablen  HOST="Outdoor"  eingetragen wurde.
Über die IP des ESP´s kann dann über eine eine Website die Wlan verbindung konfiguriert werden.

Sollte sich die Wlan verbindung einmal ändern, wird automatisch der Access Point gestartet,
allerdings wird über den Timeout  Time.AP  der ESP nach 2 Minuten in den DeepSleep Modus versetzt für weitere 60 Minuten.

Debug ON     Der Debug Modus verlangsamt den gesamten Programm Code. Es ist fast unmöglich ohne Debug ON weitere Dateien hochzuladen!
Debug OFF   Es muss sichergestellt sein das der MQTT Broker erreicht werden kann.
Der Programm läuft so schnell, das oftmals nur aller kleinste Dateien zur Laufzeit hochgeladen werden können.


Der MQTT Client hat zwei Topics, das Publish und das Subscribe Topic. Das Publish Topic erhält nur einen JSON string mit den gemessenen Werten.
Das Subscribe Topic hat eine besondere Rolle. Es werden Kommandos über Subscribe akzeptiert, das Zeitfenster ist dafür recht klein gewählt (<250ms)

Die wichtigsten Befehle im Subscribe Topic:
Debug ON   ||   Debug OFF
Setup Dsleep="Minuten"; BROKER="IP"; PUB="Publish/In/Topic"; SUB="Subscribe/In/Topic";

Im MQTT Subscribe Topic ist der Interessanteste Befehl der   Setup DSleep="Minuten";
Mit dem Wort Setup wird eine Datei  (setup.lua)  erzeugt, welche bei erfolgreicher IP zuweisung gelesen wird.
Dort könen Variablen definiert werden die sich seit dem ersten einspielen des Programmes geändert haben.


-----     Gemessene Werte:     -----

Verwendete Bauteile:  ESP8266-01 mit DeepSleep Modus ohne Rote LED. DHT22 mit 10 Kohm zwischen Vcc-Data.

Stromaufnahme:
(ESP8266-01(DeepSleep) + DHT22(schläft)  ~  DSleep = 0,12mA
RunTime=100mA (Annahme, da WiFi connect = 280mA über wenige ms)

-------------------------------------------------------------------------------------------------------

Laufzeit: Gemessen wurden Verbindungs Werte (Debug="OFF") zwischen Mindestens: <3,5s Maximal: <8s

4 * Lesen Pro Stunde = 4*3,5s= 14s (Runtime) ~ 0,39mAh

3600s - 14s(Runtime) = 3586s bei ca 0,119mAh

Verbrauch pro Stunde:  (14s Runtime)+(3586s DeepSleep) = ((100mA/3600s)*14s) + ((0,12mA/3600)*3586s) = 0,389mAh + 0,119mAh = 0,508mAh

(500mAh/0,508mAh) ~ 984h ~ 41 Tage
