---------------------
---    Settings   ---
---------------------
Version="1.2";
-- Allgemeine Konfiguration
HOST="Outdoor";		-- HostName benutzt als: Host Name, MQTT-Client Name, und als Access Point Name


DSleep = "2"		-- In Minuten Deep Sleep Countdown (MAX DeepSleep Time < 71 Minuten )
-- MQTT Konfiguration
BROKER = "server.h" 		-- Broker -> IP | HostName
QoS = "0"					-- QoS:   0: „Fire-and-forget“  ||  1: „Acknowledgement“(Erwartet Bestätigung)  ||  2: „Synchronisiert“ (Viel Traffic)
PUB = "h/sensors/outdoor" 	-- Publish in Topic
SUB = "h/cmd/outdoor" 		-- Subscribe in Topic; Benutzt für: Eingehende Befehle; "Bin Online"; "Bin bereits Offline:(Letzter Wille/Testament)"


----------------------------------------------------------------
--->>>   !!!   Be careful with the following code   !!!   <<<---
----------------------------------------------------------------
wifi.setphymode(wifi.PHYMODE_N);
wifi.sta.sethostname(HOST);
wifi.setmode(wifi.STATION); 	-- _N -> Low Range, High Speed, Low Current (USE ONLY IN STATION)	
Time={};
Time.Start=500; 	-- Time.Start In ms, MIN: ~500 ms Start verzögerung; Verwendet für Script Start. Bei Debug=="OFF" verwendet als GetWifiOrAP() Verzögerung; Mosquitto-KeepAlive timeout;
Time.Offline=10;  	-- In Sekunden: MIN: 10 s  Nach dieser Zeit wird der AP gestartet. BEI DEBUG=="ON" verwendet als:  GetWifiOrAP() Verzögerung; Power_OFF() Verzögerung; Mosquitto-KeepAlive timeout;
Time.AP=2;			-- In Minuten; WENN der Access Point gestartet wird, bleibt dieser solange an
------------------------------
function GetWifiOrAP()
	print("\n\t\[ Starte ESP   -   Version:"..Version.."   -   Debug:"..Debug.." \]");
	if Debug == "ON" then
		l = file.list(); print("- Dateien gefunden: \t\t\t\t\t (Laufzeit: "..math.floor(tmr.now()/1000).."ms)");
		for k,v in pairs(l) do
			print("- FileName: "..k.." \t FileSize: "..v.." byte");
		end;
	end;
	wifi.sta.connect(); -- Connect Wlan
	tmr.alarm(1, 200, 1, function()
			status, temp, humi = dht.read(4);	  					-- Read DHT Data Pin4==GPIO2;
			if status == dht.OK then								-- DHT returns true...
				tmr.stop(1);
				if Debug == "ON" then
					print("\n- DHT gelesen:  Temperature: "..temp.."C  Humidity: "..humi.."rH  \t\t (Laufzeit: "..math.floor(tmr.now()/1000).."ms)");
				end
			end
		end
	)
	tmr.alarm(2, 250, 1, function()	-- "ONLINE Check, In Millisekunden"
			if wifi.sta.getip() then  	-- Wenn eine IP zugewiesen wurde, (Nicht auf www geprüfte IP)
				tmr.stop(1);
				tmr.stop(2);
				tmr.stop(3);
				if file.exists("setup.lua") then	     --  Überschreibt die Anfangs Konfiguration
					dofile("setup.lua");
				end
				print("- IP: "..wifi.sta.getip().." \t - MAC: "..wifi.ap.getmac());
				if status == dht.OK then
					Mosquitto('{"Temperature": '..temp..', "Humidity": '..humi..'}'); 	-- Create String for MQTT
				elseif Debug == "ON" then
					print("- Debug ON: Kein DHT Sensor gefunden");
					Power_OFF(); 
				else
					print("- Keine Daten vom DHT sensor!");
					Power_OFF();
				end
			end --else if Debug == "ON" then print("- Noch keine IP erhalten..."); end end
		end
	)
	tmr.alarm(3, math.floor(Time.Offline*1000), 0, function()  	-- In Sekunden, MIN: ~ 5s:  Viel zu lange OFFLINE -> AP()
		tmr.stop(1);
		tmr.stop(2);
		tmr.stop(3);
		if wifi.sta.getip() == nil then			
			print("\n\n\n\n\t\[ Starte Access Point: "..HOST.." \t AP Online fuer:"..Time.AP.." min \]\n");
			print("- Bitte mit Wlan "..HOST.." verbinden und Verbindungs-Daten eingeben, per Website oder http-GET !\n");
			print("- http-GET:   http://Esp8266-IP/update?wifi_ssid=DeineSSID&wifi_password=DeinPasswort");
			print("- Website:    (Ein paar Addressen ausprobieren, ESP hostet ein Overlay)...\n");			
			wifi.setphymode(wifi.PHYMODE_G);
			wifi.setmode(wifi.STATIONAP);
			wifi.ap.config({ssid=HOST, auth=wifi.OPEN});
			enduser_setup.manual(true);
			enduser_setup.start(function(onConnected)
					print("- Erfolgreich Verbunden mit IP: " .. wifi.sta.getip().." \t mit MAC: "..wifi.ap.getmac().."\n- Bitte den ESP jetzt neu  starten!\n");
				end
			);
			tmr.alarm(1, math.floor(Time.AP*60000), 0, function()		-- AP shutdown, in Minuten (**6e+7)				
					print("\t\[ Stoppe Access Point zum Selbstschutz \]");
					if Debug == "OFF" then
						print("- DeepSleep wird auf   60 Minuten    gesetzt ! \]");
						DSleep = "60";
						enduser_setup.stop();
					end
					Power_OFF();
				end
			)
		end
	end)
end

function Mosquitto(MSG)	
	mqtt = mqtt.Client(HOST, 4);			-- MQTT Create Client, KeepAlive[ username, passwort, cleansession, 
	mqtt:lwt(SUB, "Offline", QoS, 0)  -- Letzter Wille und Testament
	if Debug == "ON" then
		mqtt:on("offline", function(client)
				print ("- MQTT getrennt");
			end
		)
	end
	mqtt:on("overflow", function(client, topic, data)
			if data ~= nil then
				print("- MQTT partial overflowed message: ".. data);
			end;
		end
	)
	mqtt:on("message", function(client, topic, data)
			if data ~= nil then
				Subscribe(topic, data);
			end
		end
	)
	mqtt:connect(BROKER, 1883, QoS, function(client)  -- MQTT Connectet, run this AFTER Acknowledge
			if Debug == "ON" then
				print ("- MQTT Broker: "..BROKER.."\t\t- Subscribe: "..SUB.."\t\t- Publish: "..PUB);
			end
			--Subscribe
			client:subscribe(SUB, QoS);
			-- Publish
			client:publish(PUB, MSG, QoS, 0, function(client)
				print("- Publish to "..BROKER..": \t"..MSG.." \t (Laufzeit: "..math.floor(tmr.now()/1000).."ms)");
				Power_OFF();
			end
			)
		end,	-- Variable DATA wird übertragen
		function(client, reason)
			print("- MQTT ERROR see code\tmqtt:connect\tsend ErrorCode: "..reason);
			Power_OFF();
		end
	);
	mqtt:close(); 
end

function Subscribe(topic, data)
	if data == "Debug ON" then
		tmr.stop(0); print("\n- Debug Modus wird erzeugt!"); 
		if file.open("debug", "a+") then
			file.write('Generated');
			file.close();
			node.dsleep(1000000,1);
		end		 
	elseif data == "Debug OFF" then
		tmr.stop(0);
		print("\n- Debug Modus wird gelöscht!");
		file.remove("debug");
		node.dsleep(1000000,1);
	elseif string.match(data, "Setup") then
		tmr.stop(0);
		print("- Power_OFF wurde gestoppt");
		if file.open("setup.lua", "a+") then
			print("\n- Datei setup.lua neu angelegt..."); 
			for var in string.gmatch(data, "%S+") do
				if var ~= "Setup" then
					file.write(var);
				end
			end
			file.close();
			print("\n\t\[ Datei setup.lua wurde geschrieben, stimmt das Ergebnis? \] \n\t\[ Reboot mit node.dsleep() \]\n");
			if file.open("setup.lua", "r") then
				print(file.read('\n'));
				file.close();
			end
		end
	end	
end

function Power_OFF()
	if Debug == "ON" then
		Time.Shutdown = math.floor(Time.Offline*1000);
		print("\t\t\[ Debug ON: DeepSleep pausiert fuer: "..Time.Offline.."s \] ");
	else
		Time.Shutdown = Time.Start;
	end
	tmr.alarm(0, Time.Shutdown, 0, function()
			print("\n\t\t\[ Laufzeit: "..math.floor(tmr.now()/1000).."ms\t DeepSleeping: "..DSleep.."min \]");
			node.dsleep(math.floor(DSleep*6e+7),1);
		end
	)	
end

----------------------------------------
------>>>>>>      INIT      <<<<<<------
----------------------------------------
if file.exists("debug") then
	Debug="ON";
	Time.Start=3000;
	Time.Offline=30;
	print ("\n\t\[ DebugMode aktiv! Start Verzoegerung: "..Time.Start.."s \]\n- DebugMode Info: Datei  debug  loeschen um DebugMode zu deaktivieren\n");
elseif Debug ~= "ON" then
	Debug = "OFF";
end
tmr.alarm(0, Time.Start, 0, GetWifiOrAP); 	-- SelbstSchutz, damit man sich nicht selbst aussperrt!



