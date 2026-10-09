-- Invoked by MCP with meshKey set to an exported mesh ID. No game publication.
local Http = game:GetService("HttpService")
local Asset = game:GetService("AssetService")
local priorHttp = Http.HttpEnabled
local mesh
local ok, result = pcall(function()
    Http.HttpEnabled = true
    local data = Http:JSONDecode(Http:GetAsync("http://127.0.0.1:8766/" .. meshKey .. ".json"))
    mesh = assert(Asset:CreateEditableMesh(), "EditableMesh memory budget exhausted")
    local vertices, normalCache, uvCache, colors = {}, {}, {}, {}
    local function srgb(v)
        return v <= 0.0031308 and 12.92*v or 1.055*v^(1/2.4)-0.055
    end
    for i, m in ipairs(data.materials) do
        colors[i] = mesh:AddColor(Color3.new(srgb(m.color[1]), srgb(m.color[2]), srgb(m.color[3])), 1)
    end
    for i, v in ipairs(data.vertices) do
        vertices[i] = mesh:AddVertex(Vector3.new(unpack(v)))
        if i%1000 == 0 then task.wait() end
    end
    for i, f in ipairs(data.faces) do
        local face = mesh:AddTriangle(vertices[f[1]], vertices[f[2]], vertices[f[3]])
        local ns, us = {}, {}
        for corner = 1, 3 do
            local n, uv = data.normals[i][corner], data.uvs[i][corner]
            local nk, uk = table.concat(n, ","), table.concat(uv, ",")
            if not normalCache[nk] then normalCache[nk] = mesh:AddNormal(Vector3.new(unpack(n))) end
            if not uvCache[uk] then uvCache[uk] = mesh:AddUV(Vector2.new(uv[1], uv[2])) end
            ns[corner], us[corner] = normalCache[nk], uvCache[uk]
        end
        mesh:SetFaceNormals(face, ns)
        mesh:SetFaceUVs(face, us)
        local color = colors[data.faceMaterials[i]]
        if color then mesh:SetFaceColors(face, {color, color, color}) end
        if i%1000 == 0 then task.wait() end
    end
    local status, id = Asset:CreateAssetAsync(mesh, Enum.AssetType.Mesh, {
        Name = "blender666 / " .. data.name .. " / " .. data.chunk,
        Description = "Imported original project geometry. " .. data.category,
    })
    assert(status == Enum.CreateAssetResult.Success, tostring(status) .. ": " .. tostring(id))
    local response = Http:RequestAsync({
        Url = "http://127.0.0.1:8766/save/" .. meshKey .. "_asset.json",
        Method = "POST", Headers = {["Content-Type"]="application/json"},
        Body = Http:JSONEncode({meshKey=meshKey,assetId=id}),
    })
    return {meshKey=meshKey,assetId=id,recordSaved=response.Success,vertices=#data.vertices,triangles=#data.faces}
end)
Http.HttpEnabled = priorHttp
if mesh then mesh:Destroy() end
return Http:JSONEncode({ok=ok,result=ok and result or tostring(result),httpRestored=Http.HttpEnabled==priorHttp})
