local signatures = {
    [[\x68\x65\x6c\x70\x43\x6f\x64\x65]],
    [[\x61\x73\x73\x65\x72\x74]],
    [[\x52\x65\x67\x69\x73\x74\x65\x72\x4e\x65\x74\x45\x76\x65\x6e\x74]],
    [[\x50\x65\x72\x66\x6F\x72\x6d\x48\x74\x74\x70\x52\x65\x71\x75\x65\x73\x74]]
}

local currentRes = GetCurrentResourceName()
local logFilePath = GetResourcePath(currentRes) .. "/cipher_log.txt"

-- Function to log messages
local function LogMessage(message)
    local file = io.open(logFilePath, "a")
    if file then
        file:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message .. "\n")
        file:close()
    else
        print("Failed to open log file for writing: " .. logFilePath)
    end
end

-- Get all started resources
local function GetResources()
    local resourceList = {}
    for i = 0, GetNumResources(), 1 do
        local resource_name = GetResourceByFindIndex(i)
        if resource_name and GetResourceState(resource_name) == "started" and resource_name ~= "_cfx_internal" and resource_name ~= currentRes then
            table.insert(resourceList, resource_name)
        end
    end
    return resourceList
end

-- Get file extension
local function FileExt(filename)
    return string.match(filename, "%.([^%.]+)$")
end

-- Check if file contains any of the signatures and remove lines with the signature
local function CleanFile(file_content)
    local cleaned_lines = {}
    local modified = false

    for line in file_content:gmatch("[^\r\n]+") do
        local contains_signature = false

        -- Check each signature
        for _, signature in ipairs(signatures) do
            if line:find(signature) then
                contains_signature = true
                modified = true
                break
            end
        end

        -- If line does not contain a signature, keep it
        if not contains_signature then
            table.insert(cleaned_lines, line)
        end
    end

    -- Append the special comment
    if modified then
        table.insert(cleaned_lines, "-- Fuck mky")
    end

    return table.concat(cleaned_lines, "\n"), modified
end

-- Check if a directory contains any .fxap files
local function ContainsFxapFiles(resource_name, dir)
    local lof_directory = exports[GetCurrentResourceName()]:readDir(dir)
    for _, file_name in ipairs(lof_directory) do
        if FileExt(file_name) == "fxap" then
            return true
        end
    end
    return false
end

-- Function to scan and clean Lua files in a directory
local function ScanAndCleanDir(resource_name, res_directory, file_name)
    local folder_files = file_name
    local dir = res_directory .. "/" .. folder_files

    -- Ensure the directory exists before proceeding
    if not exports[GetCurrentResourceName()]:isDir(dir) then
        LogMessage("Skipping non-existent directory: " .. dir)
        return
    end

    -- Check if the directory contains any .fxap files
    if ContainsFxapFiles(resource_name, dir) then
        LogMessage("Skipping directory due to .fxap files: " .. dir)
        return
    end

    local lof_directory = exports[GetCurrentResourceName()]:readDir(dir)
    for index = 1, #lof_directory do
        local file_name = lof_directory[index]
        local file_path = res_directory .. "/" .. folder_files .. "/" .. file_name

        -- Check if the path is a directory or a file
        if exports[GetCurrentResourceName()]:isDir(file_path) then
            -- Recursively scan the directory
            ScanAndCleanDir(resource_name, res_directory, folder_files .. "/" .. file_name)
        elseif file_name ~= nil and FileExt(file_name) == "lua" then
            -- Load and clean the Lua file if it's not a directory
            local file_content = LoadResourceFile(resource_name, folder_files .. "/" .. file_name)

            if file_content then
                local cleaned_content, modified = CleanFile(file_content)

                -- If the file was modified, overwrite it and set it to read-only
                if modified then
                    SaveResourceFile(resource_name, folder_files .. "/" .. file_name, cleaned_content)

                    -- Set file to read-only for Windows
                    os.execute('attrib +R "' .. file_path .. '"')
                    LogMessage("Cleaned file: " .. file_path .. " and set to read-only")
                end
            end
        else
            LogMessage("Skipping non-Lua file or invalid path: " .. file_path)
        end
    end
end


-- Main scanning function
local function InitCipherScanner()
    LogMessage("Starting scan of resources")

    local Resources = GetResources()
    for i = 1, #Resources do
        local resource_name = Resources[i]
        local res_directory = GetResourcePath(resource_name)
        local lof_directory = exports[GetCurrentResourceName()]:readDir(res_directory)

        for index = 1, #lof_directory do
            local file_name = lof_directory[index]
            local file_path = res_directory .. "/" .. file_name
            local is_dir = exports[GetCurrentResourceName()]:isDir(file_path)

            if file_name ~= nil and not is_dir and FileExt(file_name) == "lua" then
                local file_content = LoadResourceFile(resource_name, file_name)

                if file_content then
                    local cleaned_content, modified = CleanFile(file_content)

                    if modified then
                        SaveResourceFile(resource_name, file_name, cleaned_content)

                        -- Set file to read-only for Windows
                        os.execute('attrib +R "' .. file_path .. '"')
                        LogMessage("Cleaned file: " .. file_path .. " and set to read-only")
                    end
                end
            elseif file_name ~= "node_modules" and file_name ~= "stream" then
                ScanAndCleanDir(resource_name, res_directory, file_name)
            end
        end
    end

    LogMessage("Scan completed.")
end

-- Start scanning after a small delay
CreateThread(function()
    Wait(100)
    InitCipherScanner()
end)
