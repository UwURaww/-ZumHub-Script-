local v0=game:GetService("Players");local v1=v0.LocalPlayer;local v2=v1.Character or v1.CharacterAdded:Wait() ;local v3=v2:WaitForChild("HumanoidRootPart");local v4=workspace:WaitForChild("EggHunt_Eggstreme");local v5=v3.CFrame;local function v6(v8) if v8:IsA("BasePart") then return v8;elseif v8:IsA("Model") then return v8:FindFirstChild("HumanoidRootPart") or v8:FindFirstChildWhichIsA("BasePart") ;end end for v9,v10 in ipairs(v4:GetChildren()) do local v11=v6(v10);if v11 then while v10.Parent do local v12=1065 -(68 + 997) ;local v13;while true do if (v12==(1270 -(226 + 1044))) then v13=0 -0 ;while true do if (v13==(117 -(32 + 85))) then if (v11 and v11.Parent) then local v14=0;local v15;while true do if (v14==1) then v3.CFrame=v15 + Vector3.new(0 + 0 , -(1 + 1),957 -(892 + 65) ) ;break;end if (v14==(0 -0)) then v15=v11.CFrame;v3.CFrame=v15 + Vector3.new(0 -0 ,1 -0 ,350 -(87 + 263) ) ;v14=1;end end end task.wait(180.1 -(67 + 113) );break;end end break;end end end end end v3.CFrame=v5;print("Finished collecting all targets");
-- Obfuscated Lol XD
--[[
╭╮╭╮╭┳╮╱╱╱╱╱╭╮╱╱╱╱╱╱╱╱╱╱
┃┃┃┃┃┃┃╱╱╱╱╭╯╰╮╱╱╱╱╱╱╱╱╱
┃┃┃┃┃┃╰━┳━━╋╮╭╯╭━━┳━┳━━╮
┃╰╯╰╯┃╭╮┃╭╮┃┃┃╱┃╭╮┃╭┫┃━┫
╰╮╭╮╭┫┃┃┃╭╮┃┃╰╮┃╭╮┃┃┃┃━┫
╱╰╯╰╯╰╯╰┻╯╰╯╰━╯╰╯╰┻╯╰━━╯
╭╮╱╭╮╱╱╱╱╱╱╱╱╭╮╱╱╱╱╱╱╭━━╮
┃┃╱┃┃╱╱╱╱╱╱╱╱┃┃╱╱╱╱╱╱┃╭╮┃
┃╰━╯┣━━┳╮╭╮╭━╯┣━━┳┳━━┫╰╯┃
╰━╮╭┫╭╮┃┃┃┃┃╭╮┃╭╮┣┫╭╮┣━╮┃
╭━╯┃┃╰╯┃╰╯┃┃╰╯┃╰╯┃┃┃┃┣━╯┃
╰━━╯╰━━┻━━╯╰━━┻━━┻┻╯╰┻━━╯
╭╮╱╭╮╱╱╱╱╱╱╱╭━━━╮
┃┃╱┃┃╱╱╱╱╱╱╱┃╭━╮┃
┃╰━╯┣━━┳━┳━━╋╯╭╯┃
┃╭━╮┃┃━┫╭┫┃━┫╱┃╭╯
┃┃╱┃┃┃━┫┃┃┃━┫╱╭╮╱
╰╯╱╰┻━━┻╯╰━━╯╱╰╯╱
]]--
