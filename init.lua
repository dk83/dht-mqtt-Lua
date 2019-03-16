---------------------
---    Settings   ---
---------------------
Version="1.2";
-- Allgemeine Konfiguration
HOST="balkon";		-- HostName benutzt als: Host Name, MQTT-Client Name, und als Access Point Name

-- MQTT Konfiguration
BROKER = "server.h" 		-- Broker -> IP | HostName
USER=""
PWD=""
QoS = "0"					-- QoS:   0: „Fire-and-forget“  ||  1: „Acknowledgement“(Erwartet Bestätigung)  ||  2: „Synchronisiert“ (Viel Traffic)
PUB = "h/sensors/balkon"	-- Publish in Topic
SUB = "h/cmd/balkon" 		-- Subscribe in Topic; Benutzt für: Eingehende Befehle; "Bin Online"; "Bin bereits Offline:(Letzter Wille/Testament)"

--Max Voltage ~> 4250 mV (messung: 4100mv)
----------------------------------------------------------------
--->>>   !!!   Be careful with the following code   !!!   <<<---
----------------------------------------------------------------
wifi.setphymode(wifi.PHYMODE_N); wifi.sta.sethostname(HOST); wifi.setmode(wifi.STATION); 	-- _N -> Low Range, High Speed, Low Current (USE ONLY IN STATION)
wifi.sta.connect(); -- Verbinde zum Wlan
Time={};
Time.Start=800; 	-- Time.Start In ms, ~500 ms Start verzögerung; Verwendet für Script Start. Bei Debug=="OFF" verwendet als GetWifiOrAP() Verzögerung; Mosquitto-KeepAlive timeout;
Time.Shutdown = 175;
Time.Offline=15;  	-- In Sekunden: MIN: 10 s  Nach dieser Zeit wird der AP gestartet. BEI DEBUG=="ON" verwendet als:  GetWifiOrAP() Verzögerung; Power_OFF() Verzögerung; Mosquitto-KeepAlive timeout;
Time.AP=70;			-- In Sekunden: WENN der Access Point gestartet wird, bleibt dieser solange an
mV = 3500			-- Minimale Spannung, bei erreichen der Grenze wird der DeepSleep verdoppelt
Time.DSleep = "5"		-- In Minuten Deep Sleep Countdown (MAX DeepSleep Time < 71 Minuten )
------------------------------
function BUG(txt) if Debug == "ON" then print("- "..txt); return true; end; end
function setup()
	tmr.alarm(1, 50, 1, function() status, temp, humi = dht.read(4); if status == dht.OK then tmr.stop(1); MSG='{ "C": "'..temp..'", "rH": "'..humi..'", "mV": "'..adc.readvdd33(0)..'" }'; BUG("\n- DHT gelesen:  Temperature: "..temp.."C  Humidity: "..humi.."rH  \t\t (Laufzeit: "..math.floor(tmr.now()/1000).."ms)"); end; end)
	tmr.alarm(2, 80, 1, function() if wifi.sta.getip() then tmr.stop(1); tmr.stop(2); tmr.stop(3); main(); end	end) 	-- "ONLINE Check, In Millisekunden"			
	tmr.alarm(3, math.floor(Time.Offline*1000), 0, function() tmr.stop(1); tmr.stop(2); tmr.stop(3); if wifi.sta.getip() == nil then if file.exists("AP.lc") then dofile("AP.lc"); end end end)  	-- In Sekunden, MIN: ~ 5s:  Viel zu lange OFFLINE -> AP()
	
	if Debug == "ON" then
		print("\n   \[ Starte ESP:  Time.Start: "..Time.Start.." ms  ->  | MAIN |  ->   Publish  ->  |Subscribe OR DSleep| \]");
		Time.Shutdown = math.floor(Time.Start*8);	
		for k,v in pairs(file.list()) do l = string.format("%-15s",k) print(l.."   "..v.." bytes") end
	else print("\n\t\[ Starte ESP nach: "..Time.Start.." ms \t Warte auf Subscribe: "..Time.Shutdown.." ms \]\n"); end
end


function main()
	BUG("- IP: "..wifi.sta.getip().." \t - MAC: "..wifi.ap.getmac().."  \t\t (Laufzeit: "..math.floor(tmr.now()/1000).."ms)");
	if status == dht.OK then
		mqtt = mqtt.Client(HOST, Time.Offline, USER, PWD);			-- MQTT Create Client, KeepAlive[ username, passwort, cleansession,
		mqtt:lwt(SUB, "Offline (CMD: Debug [ON/OFF], STOPP, Setup Time.DSleep='' BROKER='' PUB='' SUB='')", QoS, 0)  -- Letzter Wille und Testament
		if Debug == "ON" then mqtt:on("offline", function(client) print ("- MQTT getrennt \t\t (Gesamt-Laufzeit: "..(tmr.now()/1000).."ms)"); end ) end
		mqtt:on("overflow", function(client, topic, data) Power_OFF(); if data ~= nil then print("- MQTT partial overflowed message: ".. data); end; end )
		mqtt:on("message", function(client, topic, data)
				if data ~= nil then
					tmr.stop(0);
					if data == "Debug" then
						if Debug == "ON" then print("\n- Debug Modus wird AUSgeschaltet!"); file.remove("debug");
						else print("\n- Debug Modus wird EINgeschaltet!"); if file.open("debug", "w") then file.write(''); file.close(); end end					
					elseif string.match(data, "Setup") then
						Write = string.sub(data, 7); print ("- Schreibe in Datei setup.lua folgendes: "..Write);		
						mqtt:connect(BROKER, 1883, QoS, function(client) client:publish(PUB, "Schreibe Datei setup.lua. Dies dauert eine Weile...", QoS, 0); end )
						if file.open("setup.lua", "w") then
							file.write(Write); file.close();
							mqtt:connect(BROKER, 1883, QoS, function(client) client:publish(PUB, "Schreiben abgeschlossen, reboote...", QoS, 0); end )
						else print("- Datei setup.lua wurde nicht geöffnet! Power_OFF()"); end
					end
					if data == "STOPP" then print("- Power_OFF wurde gestoppt"); print("\n- ESP wartet auf Eingabe/Upload neuer Dateien!");
					else Power_OFF(); end
				end;
			end
		)
		mqtt:connect(BROKER, 1883, QoS,  -- MQTT Connectet, run this AFTER Acknowledge (OR QoS=0)
			function(client)
				BUG("- MQTT Broker: "..BROKER.."\t\t- Subscribe: "..SUB.."\t\t- Publish: "..PUB);
				client:subscribe(SUB, QoS);
				client:publish(PUB, MSG, QoS, 0, function(client) Power_OFF(); print("- Publish: "..BROKER..": \t"..MSG.." \t (Laufzeit: "..math.floor(tmr.now()/1000).."ms)"); end )
			end,
			function(client, reason) print("- MQTT ERROR see code\tmqtt:connect\tsend ErrorCode: "..reason); Power_OFF(); end
		);
		mqtt:close(); 	
	else print("- Keine Daten vom DHT sensor!"); Power_OFF(); end
end

function Power_OFF()
	-- if ( adc.readvdd33(0) <= mV ) then print("- Akku fast leer, erhöhe den DeepSleep Timer auf: "..(Time.DSleep*2).." min"); Time.DSleep=(Time.DSleep*2); end
	tmr.alarm(0, Time.Shutdown, 0,
		function()
			node.dsleep(math.floor(Time.DSleep*6e+7), 0);
			if Debug == "ON" then txt = "Laufzeit (ohne Shutdown-Timer)"; zeit = ((tmr.now()/1000)-Time.Shutdown);
			else txt = "LaufZeit"; zeit = (tmr.now()/1000); end			
			print("\n\t\[ "..txt..": "..zeit.."ms (Soll: ~3.5s) \]\n\t\t\[ DeepSleep: "..Time.DSleep.." min \]");
			
		end
	);
	if Debug == "ON" then print("\n\t\[ Debug ON  ->  DeepSleep beginnt in: "..Time.Shutdown.."ms \]\n"); end
end
----------------------------------------
------>>>>>>      INIT      <<<<<<------
----------------------------------------
if file.exists("debug") then Debug="ON"; Time.Start=2000; print ("\n\t\[ DebugMode aktiv! Start Verzoegerung: "..Time.Start.."s \]\n- DebugMode Info: Datei  debug  loeschen um DebugMode zu deaktivieren");
elseif Debug ~= "ON" then Debug = "OFF"; end
tmr.alarm(0, Time.Start, 0, setup); 	-- SelbstSchutz, damit man sich nicht selbst aussperrt!



