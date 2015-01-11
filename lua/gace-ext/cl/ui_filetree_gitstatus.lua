gace.AddHook("FileTreeFileNodeThink", "Git_FileNodeIcon", function(node)
    local pathobj = gace.Path(node.NodeId)
    local vfolder = gace.VFolders[pathobj:GetVFolder()]

    node.TextColor = nil

    if vfolder and vfolder.git and vfolder.git.enabled then
        local filestatuses = vfolder.git.filestatuses

        local pathstr = pathobj:WithoutVFolder():ToString()
        local status = filestatuses and filestatuses[pathstr]
        if status then
            local parts = status:Split("_")
            local phase, change = parts[1], parts[2]

            if change == "m"--[[odified]] or change == "r"--[[enamed]] then
                node.TextColor = Color(255, 127, 0)
            elseif change == "n"--[[ew]] then
                node.TextColor = Color(0, 255, 0)
            end
        end
    end
end)

gace.AddHook("HandleNetMessage", "HandleGitStatusUpdates", function(netmsg)
    local op = netmsg:GetOpcode()
    local reqid = netmsg:GetReqId()
    local payload = netmsg:GetPayload()

    if op == "git_updstatus" then
        local vfolder = gace.VFolders[payload.vfolder]
        if vfolder and vfolder.git then
            vfolder.git.filestatuses = {}
        end

        for file,status in pairs(payload.changes) do
            local pathobj = gace.Path(file)
            local vfoldername = pathobj:GetVFolder()

            local vfolder = gace.VFolders[vfoldername]
            if vfolder and vfolder.git then
                vfolder.git.filestatuses[pathobj:WithoutVFolder():ToString()] = status
            end
        end
    end
end)
