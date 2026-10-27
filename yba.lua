local plr = game:GetService("Players").LocalPlayer
print("=== STAND ROOT ===")
print(plr:FindFirstChild("Stand", true))
print("=== LOCALPLAYER CHILDREN ===")
for _, c in ipairs(plr:GetChildren()) do
    local val = ""
    if c:IsA("StringValue") or c:IsA("NumberValue") or c:IsA("BoolValue") then
        val = tostring(c.Value)
    end
    print(string.format("  [%s] %s  %s", c.ClassName, c.Name, val))
end
print("=== CHARACTER CHILDREN ===")
if plr.Character then
    for _, c in ipairs(plr.Character:GetChildren()) do
        print(string.format("  [%s] %s", c.ClassName, c.Name))
    end
end
print("=== FINE ===")
