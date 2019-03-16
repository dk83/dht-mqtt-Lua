print("\n\n\t\[ Starte Access Point: "..HOST.." \t AP Online fuer:"..Time.AP.." s \]\n");
wifi.setphymode(wifi.PHYMODE_G); wifi.setmode(wifi.STATIONAP); wifi.ap.config({ssid=HOST, auth=wifi.OPEN});
enduser_setup.manual(true);
IP, NM, GW = wifi.ap.getip();
print("- Access Point-   IP: "..IP.."\tNetmask: "..NM.." \t Gateway: "..GW);
print("- http-GET:   http://"..IP.."/update?wifi_ssid=DeineSSID&wifi_password=DeinPasswort");
print("- Website:    http://"..IP.."/");
enduser_setup.start(function(onConnected)
		print("- Erfolgreich Verbunden mit IP: " .. wifi.sta.getip().." \t mit MAC: "..wifi.ap.getmac().."\n- ESP wird jetzt neu gestartet!\n");
		adc.force_init_mode(adc.INIT_VDD33);
		node.dsleep(math.floor(5*1e+6),1);  -- in sekunden
	end
);
tmr.alarm(0, math.floor(Time.AP*1000), 0, function()
		print("\t\[ Stoppe Access Point zum Selbstschutz \]");
		print("- DeepSleep wird auf   60 Minuten    gesetzt !");
		enduser_setup.stop();
		node.dsleep(math.floor(120*1e+6),1);
	end
);
