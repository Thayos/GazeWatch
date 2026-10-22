addon.name    = 'gazewatch'
addon.author  = 'Lofn'
addon.version = '2.6'
addon.desc    = 'Displays a running list of monster abilities without duplicate lines.'

local imgui = require('imgui')

local tp_moves_list = {}
local window_open = true

-- Packet/Text listener
ashita.events.register('text_in', 'gazewatch_text', function(e)
    if not e or not e.message or e.message == '' then
        return
    end

    -- Clean out hidden FFXI color/format tags using pure Lua pattern matching
    local clean_message = string.gsub(e.message, '[\x01-\x1F\x7F-\xFF][%x%X]', '')
    clean_message = string.gsub(clean_message, '[\x01-\x1F\x7F-\xFF]', '')

    if clean_message == '' then
        return
    end

    -- Match lines starting with "The " to isolate monsters
    local monster_name, action, ability_name = string.match(clean_message, "^The ([%a%s'%-%d]+) (readies) ([%a%s'%-]+)%.")
    
    if not monster_name then
        monster_name, action, ability_name = string.match(clean_message, "^The ([%a%s'%-%d]+) (uses) ([%a%s'%-]+)%.")
    end

    -- Process the entry ONLY if it's a confirmed monster action
    if ability_name and monster_name then
        local log_entry = string.format("%s: %s", monster_name, ability_name)
        
        -- 🛑 THE DUPLICATION FIREWALL:
        -- Check the very last item in our list. If it matches this new entry, skip it!
        if #tp_moves_list > 0 and tp_moves_list[#tp_moves_list] == log_entry then
            return
        end
        
        -- Append the clean, unique entry to the end of our tracking table array
        table.insert(tp_moves_list, log_entry)
        
        -- Keeps the window performance clean by capping the list history to the last 20 moves
        if #tp_moves_list > 20 then
            table.remove(tp_moves_list, 1)
        end
    end
end)

-- Render window
ashita.events.register('d3d_present', 'gazewatch_present', function()
    if not window_open then return end

    imgui.SetNextWindowSize({340, 180}, ImGuiCond_FirstUseEver)

    if imgui.Begin('Gaze Watch', window_open) then
        if #tp_moves_list > 0 then
            -- Loop through our tracking table sequentially and render every entry
            for index, move_text in ipairs(tp_moves_list) do
                imgui.Text(string.format("[%d] %s", index, move_text))
            end
        else
            imgui.Text('Waiting for monster abilities...')
        end
    end
    imgui.End()
end)

-- Command handler
ashita.events.register('command', 'gazewatch_cmd', function(e)
    if not e or not e.command then return end

    local first_space = string.find(e.command, ' ')
    local cmd_arg = first_space and string.sub(e.command, 1, first_space - 1) or e.command

    if string.lower(cmd_arg) == '/gw' then
        window_open = not window_open
        
        -- Instantly clears out the entire tracked table list array when hidden
        if not window_open then
            tp_moves_list = {}
        end
        
        e.blocked = true 
    end
end)
