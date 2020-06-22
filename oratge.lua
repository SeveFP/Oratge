local http = require "socket.http";
local lxp = require "lxp"

url = "http://static-m.meteo.cat/content/opendata/ctermini_comarcal.xml"
forecast_path = "<PATH>/forecast.txt" -- Replace <PATH>
plugin_path = "<PATH>" -- Replace <PATH>
symbols = {
    ["sol"] = "🌞",
    ["sol i núvols alts"] = "⛅",
    ["entre poc i mig ennuvolat"] = "⛅",
    ["molt cobert"] = "☁☁",
    ["plugim"] = "☔",
    ["xàfec"] = "☔☔☔",
    ["tempesta"] = "⚡",
    ["tempesta calamarsa"] = "❄⚡",
    ["neu"] = "❄",
    ["boira"] = "🌁🌁",
    ["boirina"] = "🌁",
    ["xàfec neu"] = "❄❄",
    ["entre mig i molt ennuvolat"] = "⛅☁",
    ["cobert"] = "☁",
    ["ruixat"] = "☔☔",
    ["xàfec amb tempesta"] = "☔⚡",
    ["neu feble"] = "❄",
    ["tempesta neu"] = "❄⚡",
    ["aiguaneu"] = "☔❄",
}

comarcaName = "El Tarragonès"
comarcaQuery = {}
forecast = ""
already_sent = 0
nextRead = false

llegendes = {comarques = {},  simbols = {}, tempestes = {}, calamarses = {}}

callbacks = {
	StartElement = function(parser, elementName, attributes)	
		if elementName == "comarca" then
			table.insert(llegendes.comarques, attributes)
			if attributes["nomCOMARCA"] == comarcaName then
				comarcaQuery = attributes
			end
		elseif elementName == "simbol" then
			table.insert(llegendes.simbols, attributes)
		elseif elementName == "tempesta" then
			table.insert(llegendes.tempestes, attributes)
		elseif elementName == "calamarsa" then
			table.insert(llegendes.calamarses, attributes)
		elseif elementName == "prediccio" then
			if attributes["idcomarca"] == comarcaQuery["id"] then
				nextRead = true
			end
		elseif nextRead then --move up 
			if attributes["dia"] == "1" then
				forecast = forecast .. "Matí: "
				mati = ""
				tarda = ""
				for k,v in pairs(llegendes.simbols) do
					if v.id == attributes["simbolmati"] then
						mati = symbols[v.nomsimbol] .. " " .. v.nomsimbol
					end
					
					if v.id == attributes["simboltarda"] then
						tarda = symbols[v.nomsimbol] .. " " .. v.nomsimbol
					end
				end
				
				forecast = forecast .. mati .. "\nTarda: " .. tarda .. "\nTemp. Màx: " .. attributes["tempmax"] .. "º\nTemp. Mín: " .. attributes["tempmin"] .. "º"
				
				--TODO: calamarsa + tempesta
				nextRead = false -- + stopParse
			end
		end
	end
}

function get_source()
    source = http.request(url)
    --find and remove all .png chunks
    source = source:gsub(".png", "")
    return source
end

function get_forecast()
    source = get_source()
    p = lxp.new(callbacks)
    p:parse(source)
    p:close()
    
    toReturn = forecast
    forecast = ""
    
    return "Predicció d'avui per al Tarragonès: \n" .. toReturn
end

function write_file(data)
    toReturn = false
    time = os.date("*t", os.time())
    now = time.day .. "-" .. time.month .. "-" .. time.year .. "_" .. time.hour .. ":" .. time.min .. ":" .. time.sec
    file = io.open(plugin_path .. now, "w+")
    
    if file and data then
        file:write(data)
        toReturn = true
        file:close()
    end
    
    return toReturn
end

function riddim.plugins.oratge(bot)
    bot:hook("groupchat/joined", function (room)
        timer.add_task(1, 
            function()   
                time = os.date("*t", os.time())
                if time.hour == 6 and time.day ~= already_sent then
                    weather = get_forecast()
                    room:send_message(weather)
                    write_file(get_source())
                    already_sent = time.day
                elseif time.hour == 7 and already_sent ~= 0 then
                   already_sent = 0 
                end
            return 60
        end);
    end);
end