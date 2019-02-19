--[[
      ScrMod v0.3.1
       26/01/2019
      Daniel Gorbea
    
  Lua script for radios X7/X9 with openTx 2.2

  Customizable telemetry screen:
   - Switches/inputs and telemetry with custom names by values or gauge
   - Bmp image

  

]]--

-- Global variables

local refresh = 0
local config =
   {radio,
    modelName,
    image = {posx = 1, posy = 1},
    textfont = {size = 1},
    titlefont = {size = 3},
    blocks= {{}} }
local font = {[1] = {pixelheigh = 8, pixelwidth = 5, size = SMLSIZE},
              [2] = {pixelheigh = 9, pixelwidth = 6, size = 0},
              [3] = {pixelheigh = 13, pixelwidth = 8, size = MIDSIZE},
              [4] = {pixelheigh = 17, pixelwidth = 10, size = DBLSIZE}}
local display = {['x7'] = {x = 128, y = 64, colWidth = 64, margin = 1, colLen = {6, 5, 3}},
                 ['x9'] = {x = 212, y = 64, colWidth = 71, margin = 2, colLen = {7, 6, 4}}}

-- Read line function

local function readLine(modelFile)
  local lineString = ''
  local char
  repeat
    char = io.read(modelFile,1)
    if char ~='\n' then lineString = lineString .. char end
  until char == '\n' or char == ''
  if char == '' then eof = true else eof = false end
  return lineString, eof
end

-- Read config function

local function readConfig(modelFile)
  local configType, lineString, eof
  local contBlock = 0
  local block = {}
  repeat
    lineString, eof = readLine(modelFile)
    local pos = string.find(lineString, '#')
    if pos ~= nil then lineString = string.sub(lineString, 1, pos - 1) end
    newBlock = string.match(lineString, '%s*<(%S+)>%s*')
    if newBlock ~= nil then

      -- New block found

      configType = newBlock
      if configType == 'switch' or configType == 'value' or configType == 'bar' then
        config.blocks[contBlock] = block
        contBlock = contBlock + 1
        block = {blockType = configType}
      end
    else

      -- Process parameters

      local parameter,value = string.match(lineString,'(%S+)%s*(%S+)')
      if parameter == 'field' and value ~= 'timer1' and value ~= 'timer2' and value ~= 'timer3' and value ~= 'clock' then
        local fieldinfo = getFieldInfo(value)
        if fieldinfo ~= nil then value = fieldinfo.id end
      end
      if parameter == 'row' or parameter == 'col' or parameter == 'precision' or (configType == 'bar' and (parameter == 'min' or parameter == 'max')) then 
        value = tonumber(value) or 0
      elseif parameter == 'scale' or parameter == 'size' then
        value = string.gsub(value, '%.', ',')
        value = tonumber(value) or 1
      elseif (configType == 'switch' and (parameter == 'low' or parameter == 'mid' or  parameter == 'high')) or parameter == 'unit' then
        value = value or ''
      end
      if parameter ~= nil then
        if configType == 'switch' or configType == 'value' or configType == 'bar' then
          block[parameter] = value
        else
          config[configType][parameter] = value
        end
      end
      if eof and (configType == 'switch' or configType == 'value' or configType == 'bar') then config.blocks[contBlock] = block end
    end
  until eof
end

-- Draw Title function

local function drawTitle()
  lcd.drawPixmap(config.image.posx, config.image.posy, '/SCRIPTS/TELEMETRY/ScrMod/' .. config.modelName .. '.bmp')
    if config.titlefont.size > 0 then
      lcd.drawLine(1,font[config.titlefont.size].pixelheigh,display[config.radio].x-2, font[config.titlefont.size].pixelheigh, SOLID, FORCE)
      lcd.drawText(display[config.radio].x/2-font[config.titlefont.size].pixelwidth*string.len(config.modelName)/2,1,config.modelName,font[config.titlefont.size].size)
    end
end

-- Draw Switch function

local function drawSwitch(data, value)
  if refresh == 5 then lcd.drawText(display[config.radio].colWidth*(data.col-1)+display[config.radio].margin,  font[config.textfont.size].pixelheigh*(data.row-1)+2+font[config.titlefont.size].pixelheigh, string.sub(data.name or '',1,  display[config.radio].colLen[config.textfont.size]), font[config.textfont.size].size) end
  if refresh == 5 or value ~= data.value then 
        lcd.drawFilledRectangle(display[config.radio].colWidth*(data.col-1)+display[config.radio].colWidth/2+display[config.radio].margin, font[config.textfont.size].pixelheigh*(data.row-1)+2+font[config.titlefont.size].pixelheigh, display[config.radio].colWidth/2-3, font[config.textfont.size].pixelheigh, ERASE)
        lcd.drawText(display[config.radio].colWidth*(data.col-1)+display[config.radio].colWidth/2+display[config.radio].margin, font[config.textfont.size].pixelheigh*(data.row-1)+2+font[config.titlefont.size].pixelheigh, string.sub(value or '',1,display[config.radio].colLen[config.textfont.size]), font[config.textfont.size].size)
  end
end

-- Draw Value function

local function drawValue(data, value)
  if refresh == 5 then lcd.drawText(display[config.radio].colWidth*(data.col-1)+display[config.radio].margin, font[config.textfont.size].pixelheigh*(data.row-1)+2+font[config.titlefont.size].pixelheigh,string.sub(data.name or '',1,display[config.radio].colLen[config.textfont.size]), font[config.textfont.size].size) end
  if refresh == 5 or value ~= data.value then
      lcd.drawFilledRectangle(display[config.radio].colWidth*(data.col-1)+display[config.radio].colWidth/2+display[config.radio].margin, font[config.textfont.size].pixelheigh*(data.row-1)+2+font[config.titlefont.size].pixelheigh, display[config.radio].colWidth/2-3, font[config.textfont.size].pixelheigh, ERASE)
    if data.field == 'timer1' or data.field == 'timer2' or data.field == 'timer3' or data.field == 'clock' then
      local min_hour = math.floor(math.modf(value,3600)/60)
      local sec_min = math.floor(value % 60)
          lcd.drawText(display[config.radio].colWidth*(data.col-1)+display[config.radio].colWidth/2+display[config.radio].margin, font[config.textfont.size].pixelheigh*(data.row-1)+2+font[config.titlefont.size].pixelheigh, string.format("%d:%02d",min_hour,sec_min), font[config.textfont.size].size)
    else
          lcd.drawText(display[config.radio].colWidth*(data.col-1)+display[config.radio].colWidth/2+display[config.radio].margin, font[config.textfont.size].pixelheigh*(data.row-1)+2+font[config.titlefont.size].pixelheigh, string.sub(string.format('%.' .. (data.precision or 0) .. 'f', value*(data.scale or 1)) .. (data.unit or ''),1,display[config.radio].colLen[config.textfont.size]), font[config.textfont.size].size)
    end
  end
end

-- Draw Gauge function

local function drawBar(data, value)
  if refresh == 5 then
    lcd.drawText(display[config.radio].colWidth*(data.col-1)+display[config.radio].margin, font[config.textfont.size].pixelheigh*(data.row-1)+2+font[config.titlefont.size].pixelheigh, string.sub(data.name or '',1,6),font[config.textfont.size].size)
  end
  if refresh == 5 or value ~= data.value then
    lcd.drawFilledRectangle(display[config.radio].colWidth*(data.col-1)+display[config.radio].colWidth/2+display[config.radio].margin, font[config.textfont.size].pixelheigh*(data.row-1)+3+font[config.titlefont.size].pixelheigh, display[config.radio].colWidth/2-2, font[config.textfont.size].pixelheigh-3, ERASE)
    lcd.drawGauge(display[config.radio].colWidth*(data.col-1)+display[config.radio].colWidth/2+display[config.radio].margin,font[config.textfont.size].pixelheigh*(data.row-1)+3+font[config.titlefont.size].pixelheigh, display[config.radio].colWidth/2-3, font[config.textfont.size].pixelheigh-3,value-data.min,data.max-data.min)
  end
end

-- Init function

local function init_func()

  -- Get radio type and set display

  _,config.radio,_,_,_ = getVersion()
  config.radio = string.sub(config.radio,1,2)

  -- Get model info

  local modelTable = model.getInfo()
  config.modelName = modelTable.name

  -- Read config

  local modelFile = io.open('/SCRIPTS/TELEMETRY/ScrMod/' .. config.modelName, 'r')
  if modelFile ~= nil then
    readConfig(modelFile)
    io.close(modelFile)
  else
    config.blocks[1] = {blockType = 'error', value = 'Error: config file not found'}
  end
end

-- Background function

local function bg_func(event)
  if refresh < 5 then refresh = refresh + 1 end
end

-- Main function

local function run_func(event)
  local data = {}

  -- Title and bitmap

  if refresh == 5 then
    lcd.clear()
    drawTitle()
  end

  -- Process elements

  for _,data in ipairs(config.blocks) do
    local value

    -- Type switch

    if data.blockType == 'switch' then
      value = getValue(data.field)/1024
      if value == -1 then value=data.low
      elseif value == 0 then value = data.mid
      elseif value == 1 then value = data.high
      end
      drawSwitch(data, value)
      data.value=value

    -- Type value

    elseif data.blockType == 'value' then
      value = getValue(data.field)
      if type(value) == 'table' then
        local total = 0
        for _,valuecell in ipairs(value) do
          total = total + (valuecell or 0)
        end
        value=total
      end
      drawValue(data, value)
      data.value=value

    -- Type gauge

    elseif data.blockType == 'bar' then
      value = getValue(data.field)
      if type(value) == 'table' then
        local total = 0
        for _,valuecell in ipairs(value) do
          total = total + (valuecell or 0)
        end
        value=total
      end
      drawBar(data, value)
      data.value=value

    -- Type error

    elseif data.dataType == 'error' then
      lcd.drawText(1,30,data.value,SMLSIZE)
    end

  end
  refresh = 0
end

return {run=run_func, background=bg_func, init=init_func}

