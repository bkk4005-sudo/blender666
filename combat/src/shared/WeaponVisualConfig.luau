-- Authored against the measured standard R15 palm attachment.
local Visual = {
    MeshId = "rbxassetid://139047510233988",
    MeshScale = Vector3.new(0.62, 0.68, 0.86),
    HandToHilt = CFrame.new(0.0, -0.1577821, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, 0.0),
    SourceGrip = CFrame.new(0, -1.195, 0),
}
function Visual.forCharacter(character: Model): CFrame
    local hand = character:FindFirstChild("RightHand")
    local palm = hand and hand:FindFirstChild("RightGripAttachment")
    return if palm and palm:IsA("Attachment") then palm.CFrame else Visual.HandToHilt
end
return Visual
