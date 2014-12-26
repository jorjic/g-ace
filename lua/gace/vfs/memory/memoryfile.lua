gace.VFS.MemoryFile = Middleclass("MemoryFile", gace.VFS.File)
local MemoryFile = gace.VFS.MemoryFile

function MemoryFile:initialize(name)
    self.class.super.initialize(self, name)

    self.lastModified = os.time()
end

local caps = gace.VFS.Capability.READ + gace.VFS.Capability.WRITE + gace.VFS.Capability.STAT
function MemoryFile:capabilities()
    return caps
end

function MemoryFile:read(options)
    return Promise(function(resolver)
        resolver:resolve(self._contents or "")
    end)
end

function MemoryFile:write(data, options)
    return Promise(function(resolver)
        self._contents = data
        self.lastModified = os.time()
        resolver:resolve()
    end)
end

function MemoryFile:size()
    return Promise(function(resolver)
        resolver:resolve(string.len(self._contents or ""))
    end)
end

function MemoryFile:lastModified()
    return Promise(function(resolver)
        resolver:resolve(self.lastModified)
    end)
end
