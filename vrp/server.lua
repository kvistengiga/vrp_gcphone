--vrpMySQL = module("vrp_mysql", "MySQL")
local Tunnel = module("vrp", "lib/Tunnel")
local Proxy = module("vrp", "lib/Proxy")
local htmlEntities = module("lib/htmlEntities")

vRP = Proxy.getInterface("vRP")
vRPclient = Tunnel.getInterface("vRP","vRP_gcphone")
local lang = vRP.lang
--[[
--vrpMySQL.createCommand("vRP/get_phones", "SELECT * FROM users WHERE identifier != NULL AND phone_number != NULL")
--vrpMySQL.createCommand("vRP/get_phone", "SELECT * FROM users WHERE identifier = @identifier")
--vrpMySQL.createCommand("vRP/phone_from_id", "SELECT * FROM users WHERE identifier = @id")
--vrpMySQL.createCommand("vRP/id_from_phone", "SELECT * FROM users WHERE phone_number = @number")
--vrpMySQL.createCommand("vRP/police_phone", "UPDATE users SET phone_number = @phone, oldphone = @old WHERE identifier = @identifier")
--vrpMySQL.createCommand("vRP/check_police", "SELECT * FROM users WHERE phone_number = @phone")
--vrpMySQL.createCommand("vRP/update_oldphone", "UPDATE users SET oldphone = @old WHERE identifier = @identifier, phone_number = @phone")
]]
PhoneNumbers        = {}

politicoords = {
  {["x"] = 440.22341918945, ["y"] = -975.72308349609, ["x"] = 30.689586639404}
}

text = {
  servicecall = "Modtaget {1} call, tager du den? <em>{2}</em>",
  opkaldtaget = "Opkaldet er taget!"
}

services = {
  ["Politi"] = {
    blipid = 304,
    blipcolor = 38,
    alert_time = 30, -- 5 minutes
    alert_permission = "police.service",
    alert_notify = "~r~Central alarmen:~n~~s~",
    notify = "~b~Du har ringet til politiet.",
    answer_notify = "~b~Politiet er på vej."
  },
  ["Ambulance"] = {
    blipid = 153,
    blipcolor = 1,
    alert_time = 30, -- 5 minutes
    alert_permission = "emergency.service",
    alert_notify = "~r~Central alarmen:~n~~s~",
    notify = "~b~Du har ringet efter ambulancen.",
    answer_notify = "~b~Ambulancen er på vej."
  },
  ["Taxi"] = {
    blipid = 198,
    blipcolor = 5,
    alert_time = 300,
    alert_permission = "taxi.service",
    alert_notify = "~y~Taxi alarm:~n~~s~",
    notify = "~y~Du har ringet til en taxa.",
    answer_notify = "~y~Din taxa er på vej."
  },
  ["Uber"] = {
    blipid = 198,
    blipcolor = 5,
    alert_time = 300,
    alert_permission = "uber.service",
    alert_notify = "~y~Uber alarm:~n~~s~",
    notify = "~y~Du har ringet til en uber.",
    answer_notify = "~y~Din uber er på vej."
  },  
  ["Advokat"] = {
    blipid = 198,
    blipcolor = 1,
    alert_time = 300,
    alert_permission = "advokat.service",
    alert_notify = "~y~Advokat alarm:~n~~s~",
    notify = "~y~Du har ringet til en advokat.",
    answer_notify = "~y~Din advokat er på vej."
  }, 
  ["Mekaniker"] = {
    blipid = 446,
    blipcolor = 5,
    alert_time = 300,
    alert_permission = "repair.service",
    alert_notify = "~y~Mekaniker alarm:~n~~s~",
    notify = "~y~Du har ringet efter en mekaniker.",
    answer_notify = "~y~En mekaniker er sendt ud."
  }
}


function notifyAlertSMS (number, alert, listSrc)
  if PhoneNumbers[number] ~= nil then
    for k,v in pairs(PhoneNumbers) do
      if k == number then
        local n = getPhoneNumberFromId(v.id)
        if n ~= nil then
          TriggerEvent('gcPhone:_internalAddMessage', number, n, 'De #' .. alert.numero  .. ' : ' .. alert.message, 0, function (smsMess)
            TriggerClientEvent("gcPhone:receiveMessage", tonumber(k), smsMess)
          end)
          if alert.coords ~= nil then
            TriggerEvent('gcPhone:_internalAddMessage', number, n, 'GPS: ' .. alert.coords.x .. ', ' .. alert.coords.y, 0, function (smsMess)
              TriggerClientEvent("gcPhone:receiveMessage", tonumber(k), smsMess)
            end)
          end
        end
      end
    end
  end
end

RegisterServerEvent('vrp_addons_gcphone:startCall')
AddEventHandler('vrp_addons_gcphone:startCall', function (callnumber, message, coords)
  local source = source
  getPhoneNumber(source, function(plynumber)
    if callnumber == "ambulance" or callnumber == "police" or callnumber == "taxa" or callnumber == "Advokat" then
      if callnumber == "ambulance" then service_name = "Ambulance" elseif callnumber == "police" then service_name = "Politi" elseif callnumber == "taxa" then service_name = "Taxi" elseif callnumber == "advokat" then service_name = "Advokat" end
      local service = services[service_name]
      local answered = false
      if service then
        local players = {}
        users = vRP.getUsers({})
        for k,v in pairs(users) do
          local player = vRP.getUserSource({k})
          -- check user
          if vRP.hasPermission({k,service.alert_permission}) and player ~= nil then
            table.insert(players,player)
          end
        end
      
        local msg = message
        addMessage(source, vRP.getUserId({source}), service_name,service.phone_notify)
        -- send notify and alert to all listening players
        getPhoneNumber(source, function(myPhone) 
          for k,v in pairs(players) do 
            vRPclient.notify(v,{service.alert_notify..msg})

            -- add position for service.time seconds
            local x,y,z = coords.x,coords.y,coords.z
            vRPclient.addBlip(v,{x,y,z,service.blipid,service.blipcolor,"("..service_name..") "..msg}, function(bid)
              SetTimeout(service.alert_time*1000,function()
                vRPclient.removeBlip(v,{bid})
              end)
            end)
        
            if service then
              vRP.request({v,service.alert_notify.. msg.. " ønsker du at tage det?", 30, function(v,ok)
                if ok then -- take the call
                  if not answered then
                    -- answer the call
                    addMessage(source, vRP.getUserId({source}), service_name,service.answer_notify)
                    vRPclient.setGPS(v,{x,y})
                    answered = true
                  else
                    vRPclient.notify(v,{text.opkaldtaget})
                  end
                end
              end})
            end
          end
        end)
      end
    end
  end)
end)

function getPhoneNumber(source, callback) 
  local user_id = vRP.getUserId({source})
  MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier = @identifier',{
    ['@identifier'] = user_id
  }, function(result)
    callback(result[1].phone_number)
  end)
end

function getPhoneNumberFromId(user_id)
  --vrpMySQL.query("vRP/phone_from_id", {id = user_id}, function(rows, affected)
    if #rows > 0 then
      return rows[1].phone_number
    else
      return nil
    end
--end)
end

function getIdFromPhone(number)
  if number ~= nil then
    --vrpMySQL.query("vRP/id_from_phone", {number = number}, function(rows,affected)
      if #rows > 0 then
        return rows[1].identifier
      else
        return nil
      end
    --end)
  end
end