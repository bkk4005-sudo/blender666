local Visual = require(script.Parent.WeaponVisualConfig)
local Ground = {}
function Ground.floor(cf, size)
    -- Lowest corner of an oriented box, without allocating eight vectors.
    return cf.Position.Y - (math.abs(cf.RightVector.Y) * size.X
        + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z) / 2
end
function Ground.lift(frames, joints, hipHeight, rootSize)
    local floor = -(hipHeight + rootSize.Y / 2)
    local low = math.huge
    for name, joint in joints do
        if frames[name] then low = math.min(low, Ground.floor(frames[name], joint.size)) end
    end
    local sword = frames.RightHand * Visual.HandToHilt * CFrame.new(Visual.SourceGrip.Position * Visual.MeshScale):Inverse()
    low = math.min(low, Ground.floor(sword, Vector3.new(1.51340294, 4.71, .37736732) * Visual.MeshScale))
    return math.max(0, floor + .07 - low)
end
return Ground
