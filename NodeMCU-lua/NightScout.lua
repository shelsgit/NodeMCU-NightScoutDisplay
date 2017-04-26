-- Nightscout display
-- fonts available in current firmware: font_6x10 (height=12,width=6),font_cursor(h=31,w=31),font_fub30n (h=54,w59), font_trixel_squaren (width=5,h=9)

-- Components/Wiring:
-- Display: 0.96" Inch Yellow Blue I2c IIC Serial Oled LCD LED Module 12864 128X64 -- https://www.amazon.com/Diymall-Yellow-Serial-Arduino-Display/dp/B00O2LLT30
-- WIFI NodeMCU: NodeMCU LUA ESP8266 -- http://www.ebay.co.uk/itm/NodeMCU-LUA-WIFI-Internet-Development-Board-Based-on-ESP8266-/291505733201?hash=item43df187e51:g:iikAAOSwHPlWeoBr
-- MicroUSB Cable
-- Wiring:  D1 on WIFI NodeMCU -to- SDA on Display
--          D2 on WIFI NodeMCU -to- SCL on Display
--         3V3 on WIFI NodeMCU -to- GND on Display
--         GND on WIFI NodeMCU -to- VCC on Display
--         MicroUSB(plugged into computer or outlet) -to- WIFI NodeMCU USB port

-- Directions:
-- 1) Wire Display and WIFI NodeMCU as above
-- 2) Enter your azure site in this file (NightSout.lua line 20) and change any other constants in "--constants" section (starting on line 19)
-- 3) Open init.lua and enter your WIFI info (ip, netmask, gateway, wifissid, wifiPassword)
-- 3) Use(download if needed) "ESP8266Flasher" program to flash required firmware to your NodeMCU -- FW file: nodemcu-master-14-modules-2017-04-08-22-15-36-integer.bin - contains more than needed so this can be merged into this eventually: https://github.com/MrPsi/NodeMCU-Wixel/blob/master/README.md
-- 4) Use(download if needed) "ESPlorer" program to upload this .lua file and init.lua to your NodeMCU

--contants
NSsite = "xxx.azurewebsites.net" -- Put your azuresite here, ie:  "xxxxxx.azurewebsites.net"
StaleThreshold = 10  -- Number of mins until Stale, and NSData will be displayed old/bg crossed out
ErrorTimeout = 5 -- Number of mins until NodeMCU is reset due to inability to connect to nightscout site (but IP is available)
rotateon = 0 --Change this to 1 if you want display rotated (havn't actually tested though)
HIHIalm = 220
HIalm = 165
LOalm = 76
LOLOalm = 65

--functions
function init_i2c_display()  --initializes display and fonts
	local sda = 1 -- SDA Pin, D1/GPIO5
	local scl = 2 -- SCL Pin, D2/GPIO4
	local sla = 0x3C
	i2c.setup(0, sda, scl, i2c.SLOW)
	disp = u8g.ssd1306_128x64_i2c(sla)
	disp:setFont(u8g.font_6x10)
    disp:setFontRefHeightExtendedText()
    disp:setDefaultForegroundColor()
    disp:setFontPosTop()
    if (rotateon == 1) then disp:setRot180() end -- Rotate Display if needed
end

function init_loaddisplay()  --
	disp:firstPage()
    repeat
		disp:setFont(u8g.font_6x10)
		disp:drawStr(40, 11, "Loading...")
	until disp:nextPage() == false
end

function getnightscout() -- Connect to NS Site and then call displayNS() to display it
print("Starting Connection..")
conn=tls.createConnection() 
conn:on("receive", function(conn, payload) 
    print("In Conn:On, RECEIVE....") 
	  if payload ~= nil then
		nsdatatable = cjson.decode(string.sub(payload,string.find(payload,"\"sgv\":")-1,string.find(payload,"\"cals\":")-3))
		nstimenow = string.sub(payload,string.find(payload,"\"bgs\":")-15,string.find(payload,"\"bgs\":")-7)   --make it 9 dig being lua max int is 2147483647 (10 dig)
	    nsdatetime = string.sub(payload,string.find(payload,"\"bgdelta\":")-13,string.find(payload,"\"bgdelta\":")-5)   --make it 9 dig being lua max int is 2147483647 (10 dig)
	  else 
		nsdatatable = nil
		print("Payload is nil")
	  end
	  nstimenow = tonumber(nstimenow)
	  
	  for k,v in pairs(nsdatatable) do print(k,v) end       
	  print("NStimenow: "..nstimenow) 
	  print("NSdatetime: "..nsdatetime) 	  
	  
	  payload = nil
	  conn:close()
	  conn=nill
	  print("Passing NSdatable to displayNS()...")
	  displayNS(nsdatatable,nstimenow,nsdatetime)
end)
conn:on("connection",function(conn, payload)
      print("In Conn:On, about to SEND....")
	  --waits for conn before sending 
	  conn:send("GET /pebble HTTP/1.1\r\n"..
                      "Host: "..NSsite.."\r\n"..
					  "Connection: keep-alive\r\n"..
                      "Accept: */*\r\n"..
                      "User-Agent: Mozilla/4.0 (compatible; esp8266 Lua;)"..
                      "\r\n\r\n")
end)		
conn:connect(443,'sreneescgm.azurewebsites.net')
end

function displayNS(nsdatatable,nstimenow,nsdatetime) 
	  print("Updating Display...")
        disp:firstPage()
        repeat
				if (nsdatatable ~= nil) then
					NS_bg = tonumber(nsdatatable["sgv"])
					
					--display NS bg value
					disp:setFont(u8g.font_fub30n)   --big font
					if (NS_bg < 100) then 
						 disp:drawStr(30, 62, NS_bg)
					else disp:drawStr(5, 62, NS_bg)
					end
						
					--put line through exising bg if NS bg value is Stale
					local timediff = nstimenow - nsdatetime --in sec
					local timediffmin = timediff / 60 --in min
					print("Timenow-NStime. sec: "..timediff)
					if (nstimenow - nsdatetime > StaleThreshold * 60) then
						disp:setFont(u8g.font_trixel_squaren) --very small font
						disp:drawStr(0, 44, "-------------------------------------" )
						disp:drawStr(0, 48, "-------------------------------------" )
						disp:drawStr(0, 52, "-------------------------------------" )
						disp:setFont(u8g.font_6x10)  --small font, like top
						disp:drawStr(84, 62, "+ "..timediffmin.."min")
					end
							
					--display any alarms (in yellow on top)
					print("Checking Alarms...")
					print("NS_bg is: "..NS_bg)
					if (NS_bg < LOLOalm) then
						disp:setFont(u8g.font_6x10)  --small top font
						disp:drawStr(2, 12, "LO LO LO LO LO LO")
					elseif (NS_bg < LOalm) then
					print("BG is in low alarm")
						disp:setFont(u8g.font_6x10)
						disp:drawStr(44, 12, "LOW LOW")
					elseif (NS_bg > HIHIalm) then 
						disp:setFont(u8g.font_6x10)
						disp:drawStr(2, 12, "HI HI HI HI HI HI HI")
					elseif (NS_bg > HIalm) then 
						disp:setFont(u8g.font_6x10)
						disp:drawStr(40, 12, "HIGH HIGH")
					else
						disp:setFont(u8g.font_6x10)
						disp:drawStr(0, 12, "                       ") 
					end
												
					--dipaly arrow (unless uncomputable)   --first is x position from left, next is down from top
					if (nsdatatable["trend"] == 1) then                -- DoubleUp, settings good
						disp:setFont(u8g.font_cursor)
						disp:drawStr(96, 35, string.char(147,147))
					elseif (nsdatatable["trend"] == 2)  then           -- SingleUp, settings good
						disp:setFont(u8g.font_cursor)
						disp:drawStr(96, 35, string.char(147))
					elseif (nsdatatable["trend"] == 3)  then           -- 45Up, settings good
						disp:setFont(u8g.font_cursor)
						disp:drawStr(106, 36, string.char(77))
					elseif (nsdatatable["trend"] == 4)  then            -- Flat, settings good
						disp:setFont(u8g.font_cursor)
						disp:drawStr(106, 46, string.char(145))
					elseif (nsdatatable["trend"] == 5)  then            -- 45Down, settings good, pic not an arrow though!
						disp:setFont(u8g.font_cursor)
						disp:drawStr(106, 50, string.char(119))
					elseif (nsdatatable["trend"] == 6)  then            -- SingleDown, settings good
						disp:setFont(u8g.font_cursor)
						disp:drawStr(96, 54, string.char(139))
					elseif (nsdatatable["trend"] == 7)  then            -- DoubleDown, settings good
						disp:setFont(u8g.font_cursor)
						disp:drawStr(96, 54, string.char(139,139))
					else						            -- Uncomputable (trend=8), or othermake arrow area blank
						disp:setFont(u8g.font_fub30n)   --big font to clear out arrow
						disp:drawStr(90, 62, "   " )
					end						
				else --should not ever happen
					print("Error - NS data is nill")
				end
        until disp:nextPage() == false
		print("Display updated, set wificonn counter to 6...")
		wifi_counter = 6   --display will not be updated again for a min
		wifi_conn_trys_total = 0  --resets to zero, to show that connection was successful	
end
  
-- Main Program
-- initiate:
NS_bg = 0
nsdatatable = {}
nstimenow = {}
init_i2c_display()
wifi_counter = 0
wifi_conn_trys_total = 0
init_loaddisplay()
-- repeats fovever:
tmr.alarm(1, 5000, 1, function() --Run every 5sec - will try NS connection and will retry 5 times until sucessful, then will wait until 5s counter reaches 13 to try to conn again
	print("Wifi counter: "..wifi_counter)
	ip = wifi.sta.getip()
	if ip=="0.0.0.0" or ip==nil then
		print("Waiting for IP...")
	elseif (wifi_conn_trys_total >= ErrorTimeout * 12) then  -- if connection request fails too many times, reset the nodemcu
		node.restart()  --restart NodeMCU being it won't connect to site (usually works after restarting.  known issue with nodemcu connecting to https sites - https://github.com/nodemcu/nodemcu-firmware/issues/1707) )
		else 
		if (wifi_counter > 12) then  --reset counter back to 0 so another conn attempt is made
		  print("Trying to connect again...")
		  wifi_counter = 0 --try to conn again
		  wifi_conn_trys_total  = wifi_conn_trys_total + 1
		elseif (wifi_counter > 5) and (wifi_counter < 13) then  --after 5 conn tries, or after display succesfully updates, count up to 13 to delay next attemp to connect to NSsite
		  print("Counting up to delay next connection attempt...")
		  wifi_counter = wifi_counter + 1
		  wifi_conn_trys_total  = wifi_conn_trys_total + 1
		else -- Try to connect to NSsite site
			print("Trying to connect, wifi counter: "..wifi_counter)
			wifi_counter = wifi_counter + 1
			wifi_conn_trys_total  = wifi_conn_trys_total + 1
			getnightscout()  -- get data and display it
		end
	end
end )

