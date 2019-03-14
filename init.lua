---------------------
---    Settings   ---
---------------------
Version="1.2";
-- Allgemeine Konfiguration
HOST="outdoor";		-- HostName benutzt als: Host Name, MQTT-Client Name, und als Access Point Name
DSleep = "1"		-- In Minuten Deep Sleep Countdown (MAX DeepSleep Time < 71 Minuten )
-- MQTT Konfiguration
BROKER = "server" 		-- Broker -> IP | HostName
USER=""
PWD=""
QoS = "0"					-- QoS:   0: „Fire-and-forget“  ||  1: „Acknowledgement“(Erwartet Bestätigung)  ||  2: „Synchronisiert“ (Viel Traffic)
PUB = "h/sensors/outdoor"	-- Publish in Topic
SUB = "h/cmd/outdoor" 		-- Subscribe in Topic; Benutzt für: Eingehende Befehle; "Bin Online"; "Bin bereits Offline:(Letzter Wille/Testament)"

--Max Voltage ~> 4250 mV
----------------------------------------------------------------
--->>>   !!!   Be careful with the following code   !!!   <<<---
----------------------------------------------------------------
wifi.setphymode(wifi.PHYMODE_N); wifi.sta.sethostname(HOST); wifi.setmode(wifi.STATION); 	-- _N -> Low Range, High Speed, Low Current (USE ONLY IN STATION)
wifi.sta.connect(); -- Connect Wlan	
Time={};
Time.Start=150; 	-- Time.Start In ms, ~500 ms Start verzögerung; Verwendet für Script Start. Bei Debug=="OFF" verwendet als GetWifiOrAP() Verzögerung; Mosquitto-KeepAlive timeout;
Time.Offline=12;  	-- In Sekunden: MIN: 10 s  Nach dieser Zeit wird der AP gestartet. BEI DEBUG=="ON" verwendet als:  GetWifiOrAP() Verzögerung; Power_OFF() Verzögerung; Mosquitto-KeepAlive timeout;
Time.AP=2;			-- In Minuten; WENN der Access Point gestartet wird, bleibt dieser solange an
------------------------------
function BUG(txt) if Debug == "ON" then print("- "..txt); return true; end; end
function setup()
	print("\n\t\[ Starte ESP   ->   Time.Start: "..Time.Start.." ms \]");
	tmr.alarm(1, 150, 1, function() status, temp, humi = dht.read(4); if status == dht.OK then tmr.stop(1); MSG='{"CountESP" "Temperature": '..temp..', "Humidity": '..humi..', "mV": '..adc.readvdd33(0)..'}'; BUG("\n- DHT gelesen:  Temperature: "..temp.."C  Humidity: "..humi.."rH  \t\t (Laufzeit: "..math.floor(tmr.now()/1000).."ms)"); end; end)
	tmr.alarm(2, 80, 1, function() if wifi.sta.getip() then tmr.stop(1); tmr.stop(2); tmr.stop(3); main(); end	end) 	-- "ONLINE Check, In Millisekunden"			
	tmr.alarm(3, math.floor(Time.Offline*1000), 0, function() tmr.stop(1); tmr.stop(2); tmr.stop(3); AP(); end)   	-- In Sekunden, MIN: ~ 5s:  Viel zu lange OFFLINE -> AP()
end

function AP()
	if wifi.sta.getip() == nil then			
		print("\n\n\t\[ Starte Access Point: "..HOST.." \t AP Online fuer:"..Time.AP.." min \]\n");
		wifi.setphymode(wifi.PHYMODE_G); wifi.setmode(wifi.STATIONAP); wifi.ap.config({ssid=HOST, auth=wifi.OPEN}); enduser_setup.manual(true);
		IP, NM, GW = wifi.ap.getip(); print("- Access Point-   IP: "..IP.."\tNetmask: "..NM.." \t Gateway: "..GW);
		print("- http-GET:   http://"..IP.."/update?wifi_ssid=DeineSSID&wifi_password=DeinPasswort"); print("- Website:    http://"..IP.."/");
		enduser_setup.start(function(onConnected) print("- Erfolgreich Verbunden mit IP: " .. wifi.sta.getip().." \t mit MAC: "..wifi.ap.getmac().."\n- ESP wird jetzt neu gestartet!\n"); adc.force_init_mode(adc.INIT_VDD33); node.dsleep(math.floor(5*1e+6),1); end );
		tmr.alarm(0, math.floor(Time.AP*60000), 0, function() print("\t\[ Stoppe Access Point zum Selbstschutz \]"); print("- DeepSleep wird auf   60 Minuten    gesetzt !"); DSleep = "60"; enduser_setup.stop(); Power_OFF(); end );
	end
end

function main()
	BUG("- IP: "..wifi.sta.getip().." \t - MAC: "..wifi.ap.getmac().."  \t\t (Laufzeit: "..math.floor(tmr.now()/1000).."ms)");
	if status == dht.OK then
		mqtt = mqtt.Client(HOST, 5, USER, PWD);			-- MQTT Create Client, KeepAlive[ username, passwort, cleansession,
		mqtt:lwt(SUB, "Offline (CMD: Debug ON/OFF, STOPP, Setup DSleep='' BROKER='' PUB='' SUB='')", QoS, 0)  -- Letzter Wille und Testament
		mqtt:on("offline", function(client) print ("- MQTT getrennt"); end )
		mqtt:on("overflow", function(client, topic, data) Power_OFF(); if data ~= nil then print("- MQTT partial overflowed message: ".. data); end; end )
		mqtt:on("message", function(client, topic, data) if data ~= nil then Subscribe(topic, data); end; end )		
		mqtt:connect(BROKER, 1883, QoS,  -- MQTT Connectet, run this AFTER Acknowledge (OR QoS=0)
			function(client)
				BUG("- MQTT Broker: "..BROKER.."\t\t- Subscribe: "..SUB.."\t\t- Publish: "..PUB);
				client:publish(PUB, MSG, QoS, 0, function(client) Power_OFF(); print("- Publish to "..BROKER..": \t"..MSG); end )
				client:subscribe(SUB, QoS);
			end,
			function(client, reason) print("- MQTT ERROR see code\tmqtt:connect\tsend ErrorCode: "..reason); Power_OFF(); end
		);
		mqtt:close(); 	
	else print("- Keine Daten vom DHT sensor!"); Power_OFF(); end
end

function Subscribe(topic, data)
	if data == "Debug ON" then tmr.stop(0); print("\n- Debug Modus wird erzeugt!"); if file.open("debug", "w") then file.write('ON'); file.close(); Power_OFF(); end
	elseif data == "Debug OFF" then tmr.stop(0); print("- Debug Modus wird geloescht!"); file.remove("debug"); Power_OFF();
	elseif data == "STOPP" then tmr.stop(0); print("- Power_OFF wurde gestoppt"); print("\n- ESP wartet auf Eingabe/Upload neuer Dateien!");
	elseif string.match(data, "Setup") then
		tmr.stop(0); Write = string.sub(data, 7); print ("- Schreibe in Datei setup.lua folgendes: "..Write);		
		mqtt:connect(BROKER, 1883, QoS, function(client) client:publish(PUB, "Schreibe Datei setup.lua. Dies dauert eine Weile...", QoS, 0); end )
		if file.open("setup.lua", "w") then
			file.write(Write); file.close();
			mqtt:connect(BROKER, 1883, QoS, function(client) client:publish(PUB, "Schreiben abgeschlossen, reboote...", QoS, 0); end )
			Power_OFF();
		end
	end	
end

function Power_OFF()
	tmr.alarm(0, Time.Start, 0,
		function()
			node.dsleep(math.floor(DSleep*6e+7), 0);
			print("\t\[ Laufzeit: "..(tmr.now()/1000).."ms (SOLL: 3270-3500 ms) \t DeepSleeping: "..DSleep.."min \]");
		end
	);
end
----------------------------------------
------>>>>>>      INIT      <<<<<<------
----------------------------------------
if file.exists("debug") then Debug="ON"; Time.Start=2500; print ("\n\t\[ DebugMode aktiv! Start Verzoegerung: "..Time.Start.."s \]\n- DebugMode Info: Datei  debug  loeschen um DebugMode zu deaktivieren");
elseif Debug ~= "ON" then Debug = "OFF"; end
tmr.alarm(0, Time.Start, 0, setup); 	-- SelbstSchutz, damit man sich nicht selbst aussperrt!



