import { useState, useCallback, useEffect, useRef } from "react";

// ═══════════════════════════════════════════════════════════════
//  OBFUSCATION ENGINE
// ═══════════════════════════════════════════════════════════════

const CHARSET_HEX = "0123456789abcdef";
const CHARSET_MIXED = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function randHex(len) { let s = "_0x"; for (let i = 0; i < len; i++) s += CHARSET_HEX[randInt(0,15)]; return s; }
function randName(len) { let s = "_"; for (let i = 0; i < len; i++) s += CHARSET_MIXED[randInt(0,51)]; return s; }
function randUniLike(len) { const pool=["_","l","I","O","0","o","ll","lI","Il","II"]; let s=""; for(let i=0;i<len;i++)s+=pool[randInt(0,pool.length-1)]; return "_"+s; }
function randLong(len) { const words=["_data","_val","_tmp","_ref","_ptr","_buf","_obj","_node","_ctx","_env"]; let s=words[randInt(0,words.length-1)]; for(let i=0;i<len;i++)s+=randInt(0,9); return s; }
function generateName(style, usedNames) {
  let name, attempts=0;
  do { attempts++;
    if(style==="hex")name=randHex(randInt(4,8));
    else if(style==="unicode")name=randUniLike(randInt(4,8));
    else if(style==="long")name=randLong(randInt(4,8));
    else if(style==="mixed"){const r=randInt(0,2);name=r===0?randHex(randInt(3,6)):r===1?randUniLike(randInt(3,6)):randName(randInt(4,7));}
    else name=randName(randInt(3,6));
    if(attempts>500)break;
  } while(usedNames.has(name));
  usedNames.add(name); return name;
}

const LUAU_KEYWORDS = new Set(["and","break","do","else","elseif","end","false","for","function","goto","if","in","local","nil","not","or","repeat","return","then","true","until","while","continue"]);

function tokenize(src) {
  const tokens=[]; let i=0;
  while(i<src.length){
    if(src[i]==='-'&&src[i+1]==='-'){
      if(src[i+2]==='['){let eq=0,j=i+3;while(j<src.length&&src[j]==='='){eq++;j++;}if(src[j]==='['){const cl=']'+'='.repeat(eq)+']';const en=src.indexOf(cl,j+1);if(en!==-1){i=en+cl.length;continue;}}}
      while(i<src.length&&src[i]!=='\n')i++;continue;
    }
    if(src[i]==='['){let eq=0,j=i+1;while(j<src.length&&src[j]==='='){eq++;j++;}if(src[j]==='['){const cl=']'+'='.repeat(eq)+']';const en=src.indexOf(cl,j+1);if(en!==-1){tokens.push({type:'longstr',val:src.slice(i,en+cl.length)});i=en+cl.length;continue;}}}
    if(src[i]==='"'||src[i]==="'"){const q=src[i];let j=i+1,s=q;while(j<src.length&&src[j]!==q){if(src[j]==='\\'){s+=src[j]+src[j+1];j+=2;}else{s+=src[j];j++;}}s+=q;tokens.push({type:'string',val:s});i=j+1;continue;}
    if(/\d/.test(src[i])||(src[i]==='.'&&/\d/.test(src[i+1]))){let j=i;while(j<src.length&&/[\d\.xXa-fA-F_eE+\-]/.test(src[j]))j++;tokens.push({type:'number',val:src.slice(i,j)});i=j;continue;}
    if(/[a-zA-Z_]/.test(src[i])){let j=i;while(j<src.length&&/\w/.test(src[j]))j++;const w=src.slice(i,j);tokens.push({type:LUAU_KEYWORDS.has(w)?'kw':'id',val:w});i=j;continue;}
    if(/\s/.test(src[i])){i++;continue;}
    const two=src.slice(i,i+2);if(["==","~=","<=",">=","..","//","::"].includes(two)){tokens.push({type:'op',val:two});i+=2;continue;}
    tokens.push({type:'op',val:src[i]});i++;
  }
  return tokens;
}

const PRESERVE = new Set(["print","warn","error","tostring","tonumber","type","pairs","ipairs","next","select","unpack","table","string","math","os","io","coroutine","require","loadstring","pcall","xpcall","rawget","rawset","rawequal","setmetatable","getmetatable","assert","collectgarbage","dofile","loadfile","rawlen","_G","_ENV","_VERSION","game","workspace","script","wait","task","tick","time","spawn","delay","Instance","Vector3","Vector2","CFrame","Color3","BrickColor","UDim","UDim2","Enum","Ray","NumberRange","NumberSequence","ColorSequence","TweenInfo","Axes","Faces","shared","plugin","settings","stats","Rayfield","loadstring","HttpService","Players","RunService","UserInputService","GuiService","StarterGui","ReplicatedStorage","ServerScriptService","Lighting","SoundService","PathfindingService","TeleportService","MarketplaceService"]);

function renameIdentifiers(tokens, ns) {
  const usedNames=new Set(LUAU_KEYWORDS); const map=new Map();
  function gm(name){if(PRESERVE.has(name))return name;if(!map.has(name))map.set(name,generateName(ns,usedNames));return map.get(name);}
  return tokens.map(t=>t.type==='id'?{...t,val:gm(t.val)}:t);
}
function tokensToCode(tokens){let out="";for(let i=0;i<tokens.length;i++){const cur=tokens[i],prev=tokens[i-1];if(prev){const ns=(/[a-zA-Z0-9_]$/.test(prev.val)&&/^[a-zA-Z0-9_]/.test(cur.val))||(prev.val==="not"&&cur.val!=="(");if(ns)out+=" ";}out+=cur.val;}return out;}
function xorEncode(str,key){let r="";for(let i=0;i<str.length;i++)r+=String.fromCharCode(str.charCodeAt(i)^key);return r;}
function toB64L(str){const c="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";let r="";for(let i=0;i<str.length;i+=3){const b0=str.charCodeAt(i),b1=i+1<str.length?str.charCodeAt(i+1):0,b2=i+2<str.length?str.charCodeAt(i+2):0;r+=c[(b0>>2)&63]+c[((b0&3)<<4)|((b1>>4)&15)]+(i+1<str.length?c[((b1&15)<<2)|((b2>>6)&3)]:"=")+(i+2<str.length?c[b2&63]:"=");}return r;}
function gjm(v){const ops=[`local ${v}=((${randInt(1,50)}*${randInt(1,50)})+${randInt(1,100)}-${randInt(1,50)})`,`local ${v}=(${randInt(100,999)}%(${randInt(2,9)}))+${randInt(1,9)}`,`local ${v}=math.floor(${randInt(1,100)}/${randInt(1,10)})*${randInt(1,5)}`];return ops[randInt(0,ops.length-1)];}
function gfi(){const a=randInt(1,100),b=a+randInt(1,100);return `if ${a}>${b} then error("x")end `;}
function gfr(ns,un){const fn=generateName(ns,un),p=generateName(ns,un);return `local function ${fn}(${p})if ${p}==nil then return 0 end;return ${fn}(nil)end `;}
function gilt(ns,un){const v=generateName(ns,un),a=randInt(1,100);return `local ${v}=${a};repeat ${v}=${v}+1 until ${v}<${a-1000} `;}
function gftl(ns,un){const t=generateName(ns,un),k=generateName(ns,un);return `local ${t}={["${k}"]=${randInt(1,999)}};`;}

function applyDoubleXOR(code,o){if(!o.doubleXor)return code;const k1=randInt(1,127),k2=randInt(1,127);const enc=xorEncode(xorEncode(code,k1),k2);const b=[];for(let i=0;i<enc.length;i++)b.push(enc.charCodeAt(i));return `local _xd={${b.join(",")}};local _xs="";for _xi=1,#_xd do _xs=_xs..string.char(_xd[_xi]~${k1}~${k2})end;load(_xs)()`;}
function applyTripleXOR(code,o){if(!o.tripleXor)return code;const k1=randInt(1,127),k2=randInt(1,127),k3=randInt(1,127);const enc=xorEncode(xorEncode(xorEncode(code,k1),k2),k3);const b=[];for(let i=0;i<enc.length;i++)b.push(enc.charCodeAt(i));return `local _xt={${b.join(",")}};local _xs="";for _xi=1,#_xt do _xs=_xs..string.char(_xt[_xi]~${k1}~${k2}~${k3})end;load(_xs)()`;}
function applyBase64Like(code,o){if(!o.base64Like)return code;const enc=toB64L(code);return `local _bc="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";local _bs="${enc}";local _bd="";local _bi=1;while _bi<=#_bs do local _c1,_c2,_c3,_c4=string.byte(_bs,_bi,_bi+3);local function _bf(c)if c>=65 and c<=90 then return c-65 elseif c>=97 and c<=122 then return c-71 elseif c>=48 and c<=57 then return c+4 elseif c==43 then return 62 elseif c==47 then return 63 end;return 0 end;local _n1,_n2,_n3,_n4=_bf(_c1),_bf(_c2),_bf(_c3 or 65),_bf(_c4 or 65);local _b1=(_n1*4)+math.floor(_n2/16);local _b2=((_n2%16)*16)+math.floor(_n3/4);local _b3=((_n3%4)*64)+_n4;_bd=_bd..string.char(_b1);if _c3 and _c3~=61 then _bd=_bd..string.char(_b2)end;if _c4 and _c4~=61 then _bd=_bd..string.char(_b3)end;_bi=_bi+4 end;load(_bd)()`;}
function applyStringSplit(code,o){if(!o.stringSplit)return code;const parts=[],cs=Math.max(10,Math.floor(code.length/8));for(let i=0;i<code.length;i+=cs)parts.push(code.slice(i,i+cs).replace(/\\/g,'\\\\').replace(/"/g,'\\"').replace(/\n/g,'\\n'));const vns=parts.map((_,i)=>`_sp${i}`);return parts.map((p,i)=>`local ${vns[i]}="${p}"`).join(";")+`;load(${vns.join("..")})()`;}
function injectJunk(code,o,ns){const un=new Set();let inj="";if(o.fakeRecursive)inj+=gfr(ns,un);if(o.junkMath)for(let i=0;i<randInt(2,5);i++)inj+=gjm(generateName(ns,un))+";";if(o.fakeTableLookups)for(let i=0;i<randInt(1,3);i++)inj+=gftl(ns,un);if(o.fakeIf)for(let i=0;i<randInt(2,4);i++)inj+=gfi();if(o.infiniteLoopTraps)inj+=gilt(ns,un);return inj+code;}
function wrapFns(code,o,ns){if(!o.wrapFunctions)return code;const un=new Set(),f1=generateName(ns,un),f2=generateName(ns,un),f3=generateName(ns,un);return `local function ${f3}()local function ${f2}()local function ${f1}()${code}end;${f1}()end;${f2}()end;${f3}()`;}
function addFakeBC(code,o){if(!o.fakeBytecodeComments)return code;return `local _="\x1bLuaQ\x00\x01\x04\x04\x04\x08\x00";`+code;}
function applyAntiTamper(code,o){if(!o.antiTamper)return code;return `local _at=tostring(load);if type(_at)~="string" then _at="" end;`+code;}
function oneLine(code,o){if(!o.oneLine)return code;return code.replace(/\n/g," ").replace(/\s+/g," ").trim();}
function applyVM(code,o){if(!o.vm)return code;const steps=code.split(";").filter(s=>s.trim().length>0);if(steps.length<3)return code;let vm=`local _vm={`;steps.forEach((s,i)=>{vm+=`[${i+1}]=function()${s.trim()}end,`;});vm+=`};local _pc=1;while _pc<=${steps.length} do _vm[_pc]();_pc=_pc+1 end`;return vm;}

// Branding watermark appended as Lua comment block
function addBranding(code, o) {
  if (!o.branding) return code;
  const ts = new Date().toISOString().slice(0, 16).replace("T", " ") + " UTC";
  const brand = `--[[\n  Obfuscated by Mr.Clod\n  mrclod.obfuscator | Luau Engine v2\n  ${ts}\n  This script is protected. Unauthorized deobfuscation is prohibited.\n]]`;
  return brand + "\n" + code;
}

export function obfuscate(sourceCode, opts) {
  try {
    let code = sourceCode;
    let tokens = tokenize(code);
    if(opts.renameVars) tokens = renameIdentifiers(tokens, opts.nameStyle);
    code = tokensToCode(tokens);
    if(opts.junkMath||opts.fakeFuncs||opts.fakeIf||opts.fakeRecursive||opts.infiniteLoopTraps||opts.fakeTableLookups) code=injectJunk(code,opts,opts.nameStyle);
    code=addFakeBC(code,opts);
    code=applyAntiTamper(code,opts);
    code=wrapFns(code,opts,opts.nameStyle);
    code=oneLine(code,opts);
    if(opts.stringSplit)code=applyStringSplit(code,opts);
    else if(opts.base64Like)code=applyBase64Like(code,opts);
    else if(opts.tripleXor)code=applyTripleXOR(code,opts);
    else if(opts.doubleXor)code=applyDoubleXOR(code,opts);
    if(opts.vm&&!opts.doubleXor&&!opts.tripleXor&&!opts.base64Like&&!opts.stringSplit)code=applyVM(code,opts);
    code=addBranding(code,opts);
    return { success: true, code };
  } catch(e) { return { success: false, error: e.message, code: "" }; }
}

// ═══════════════════════════════════════════════════════════════
//  GITHUB API HELPERS
// ═══════════════════════════════════════════════════════════════

async function ghFetch(path, token, options = {}) {
  const res = await fetch(`https://api.github.com${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.message || `GitHub API error ${res.status}`);
  }
  return res.json();
}

async function getUser(token) { return ghFetch("/user", token); }
async function getRepos(token) { return ghFetch("/user/repos?per_page=100&sort=updated", token); }
async function getBranches(token, owner, repo) { return ghFetch(`/repos/${owner}/${repo}/branches`, token); }

async function uploadFile(token, owner, repo, branch, path, content, message, existingSha) {
  const body = {
    message,
    content: btoa(unescape(encodeURIComponent(content))),
    branch,
  };
  if (existingSha) body.sha = existingSha;
  return ghFetch(`/repos/${owner}/${repo}/contents/${path}`, token, {
    method: "PUT",
    body: JSON.stringify(body),
  });
}

async function getFileSha(token, owner, repo, branch, path) {
  try {
    const data = await ghFetch(`/repos/${owner}/${repo}/contents/${path}?ref=${branch}`, token);
    return data.sha;
  } catch { return null; }
}

async function listFolder(token, owner, repo, branch, path) {
  return ghFetch(`/repos/${owner}/${repo}/contents/${path || ""}?ref=${branch}`, token);
}

function rawUrl(owner, repo, branch, path) {
  return `https://raw.githubusercontent.com/${owner}/${repo}/${branch}/${path}`;
}
function loadstringSnippet(url) {
  return `loadstring(game:HttpGet("${url}"))()`;
}

// ═══════════════════════════════════════════════════════════════
//  THEME & CONSTANTS
// ═══════════════════════════════════════════════════════════════

const C = {
  bg:"#07070e", panel:"#0c0c1a", card:"#101022", card2:"#13132a",
  border:"#1c1c38", accent:"#7c3aed", accent2:"#a855f7",
  cyan:"#06b6d4", text:"#e2e8f0", muted:"#5a6a82", dim:"#3a4a5a",
  green:"#10b981", red:"#ef4444", yellow:"#f59e0b", orange:"#f97316",
};

const DEFAULT_OPTS = {
  renameVars:true, nameStyle:"mixed",
  doubleXor:false, tripleXor:false, base64Like:false, stringSplit:false,
  junkMath:true, fakeFuncs:true, fakeIf:true, fakeRecursive:true,
  infiniteLoopTraps:true, fakeTableLookups:true, fakeBytecodeComments:true,
  wrapFunctions:true, vm:false, oneLine:true, antiTamper:false,
  branding:true,
};

const SAMPLE = `-- Speed & Jump with Rayfield UI
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Mr.Clod Executor",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by Mr.Clod",
    Theme = "Default",
})

local Tab = Window:CreateTab("Movement", 4483362458)
local speedValue = 16

Tab:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 200},
    Increment = 1,
    CurrentValue = speedValue,
    Callback = function(Value)
        speedValue = Value
        humanoid.WalkSpeed = Value
    end,
})`;

// ═══════════════════════════════════════════════════════════════
//  SMALL UI COMPONENTS
// ═══════════════════════════════════════════════════════════════

function Toggle({ label, checked, onChange, danger, sub }) {
  return (
    <div style={{ display:"flex",alignItems:"flex-start",justifyContent:"space-between",padding:"11px 0",borderBottom:`1px solid ${C.border}` }}>
      <div style={{ flex:1, paddingRight:12 }}>
        <div style={{ fontSize:13,color:danger&&checked?C.red:C.text,lineHeight:1.3 }}>{label}</div>
        {sub && <div style={{ fontSize:10,color:C.muted,marginTop:2 }}>{sub}</div>}
      </div>
      <div onClick={()=>onChange(!checked)} style={{ width:46,height:26,borderRadius:13,position:"relative",flexShrink:0,cursor:"pointer",background:checked?(danger?C.red:C.accent):"#1c1c38",border:`1.5px solid ${checked?(danger?C.red:C.accent):C.border}`,transition:"all 0.2s",WebkitTapHighlightColor:"transparent",touchAction:"manipulation" }}>
        <div style={{ position:"absolute",top:3,left:checked?23:3,width:18,height:18,borderRadius:"50%",background:"#fff",transition:"left 0.2s",boxShadow:"0 1px 4px rgba(0,0,0,0.5)" }}/>
      </div>
    </div>
  );
}

function SectionHdr({ children, icon }) {
  return (
    <div style={{ fontSize:10,color:C.cyan,textTransform:"uppercase",letterSpacing:2.5,fontWeight:700,padding:"18px 0 8px",display:"flex",alignItems:"center",gap:6 }}>
      {icon && <span>{icon}</span>}{children}
    </div>
  );
}

function StyledSelect({ label, value, onChange, options }) {
  return (
    <div style={{ padding:"10px 0",borderBottom:`1px solid ${C.border}` }}>
      <div style={{ fontSize:10,color:C.muted,textTransform:"uppercase",letterSpacing:1.5,marginBottom:7 }}>{label}</div>
      <select value={value} onChange={e=>onChange(e.target.value)} style={{ width:"100%",background:C.card2,border:`1.5px solid ${C.border}`,color:C.text,padding:"10px 12px",borderRadius:9,fontSize:14,fontFamily:"inherit",cursor:"pointer",outline:"none",WebkitAppearance:"none",appearance:"none" }}>
        {options.map(o=><option key={o.value} value={o.value}>{o.label}</option>)}
      </select>
    </div>
  );
}

function Chip({ children, color = C.accent, bg, onClick, icon }) {
  return (
    <button onClick={onClick} style={{ background:bg||`${color}22`,border:`1px solid ${color}55`,color,borderRadius:8,padding:"6px 12px",fontSize:12,fontWeight:600,fontFamily:"inherit",cursor:"pointer",display:"inline-flex",alignItems:"center",gap:5,WebkitTapHighlightColor:"transparent",transition:"all 0.15s",whiteSpace:"nowrap" }}>
      {icon&&<span>{icon}</span>}{children}
    </button>
  );
}

function Input({ label, value, onChange, placeholder, type="text", mono }) {
  return (
    <div style={{ display:"flex",flexDirection:"column",gap:6 }}>
      {label && <div style={{ fontSize:10,color:C.muted,textTransform:"uppercase",letterSpacing:1.5 }}>{label}</div>}
      <input
        type={type} value={value} onChange={e=>onChange(e.target.value)} placeholder={placeholder}
        style={{ background:C.card2,border:`1.5px solid ${C.border}`,color:C.text,padding:"10px 12px",borderRadius:9,fontSize:13,fontFamily:mono?"'JetBrains Mono',monospace":"inherit",outline:"none",width:"100%",WebkitAppearance:"none" }}
      />
    </div>
  );
}

function SettingsPanel({ opts, setOpts }) {
  const so = (key) => (val) => setOpts(p=>({...p,[key]:val}));
  return (
    <div>
      <SectionHdr icon="🏷">Branding</SectionHdr>
      <Toggle label="Add Mr.Clod Watermark" checked={opts.branding} onChange={so("branding")}
        sub="Prepends an obfuscation credit comment block" />

      <SectionHdr icon="🔤">Naming</SectionHdr>
      <StyledSelect label="Variable Name Style" value={opts.nameStyle} onChange={so("nameStyle")} options={[
        {value:"hex",label:"Hex  (_0xfa3b)"},{value:"unicode",label:"Unicode-like  (_lI0Oll)"},
        {value:"long",label:"Super Long"},{value:"mixed",label:"✨ Mixed (Recommended)"},{value:"random",label:"Random Alpha"},
      ]}/>
      <Toggle label="Rename Variables & Functions" checked={opts.renameVars} onChange={so("renameVars")}/>

      <SectionHdr icon="🔒">Encoding</SectionHdr>
      <Toggle label="Double XOR" checked={opts.doubleXor} onChange={v=>setOpts(p=>({...p,doubleXor:v,tripleXor:false,base64Like:false,stringSplit:false}))} sub="XOR encode twice with two keys"/>
      <Toggle label="Triple XOR" checked={opts.tripleXor} onChange={v=>setOpts(p=>({...p,tripleXor:v,doubleXor:false,base64Like:false,stringSplit:false}))} sub="XOR encode with three keys"/>
      <Toggle label="Base64-like Encoding" checked={opts.base64Like} onChange={v=>setOpts(p=>({...p,base64Like:v,doubleXor:false,tripleXor:false,stringSplit:false}))} sub="Custom base64 with self-decoding runtime"/>
      <Toggle label="String Split & Reassemble" checked={opts.stringSplit} onChange={v=>setOpts(p=>({...p,stringSplit:v,doubleXor:false,tripleXor:false,base64Like:false}))} sub="Splits code string into parts"/>

      <SectionHdr icon="🗑">Junk Injection</SectionHdr>
      <Toggle label="Junk Math Expressions" checked={opts.junkMath} onChange={so("junkMath")}/>
      <Toggle label="Fake Function Calls" checked={opts.fakeFuncs} onChange={so("fakeFuncs")}/>
      <Toggle label="Fake If/Else Traps" checked={opts.fakeIf} onChange={so("fakeIf")}/>
      <Toggle label="Fake Recursive Functions" checked={opts.fakeRecursive} onChange={so("fakeRecursive")}/>
      <Toggle label="Infinite Loop Traps" checked={opts.infiniteLoopTraps} onChange={so("infiniteLoopTraps")}/>
      <Toggle label="Fake Table Lookups" checked={opts.fakeTableLookups} onChange={so("fakeTableLookups")}/>
      <Toggle label="Fake Bytecode Header" checked={opts.fakeBytecodeComments} onChange={so("fakeBytecodeComments")}/>

      <SectionHdr icon="🏗">Structure</SectionHdr>
      <Toggle label="Wrap in Functions" checked={opts.wrapFunctions} onChange={so("wrapFunctions")} sub="Triple-nested function wrapper"/>
      <Toggle label="VM Dispatch Mode" checked={opts.vm} onChange={so("vm")} sub="Statement dispatch table with PC counter"/>

      <SectionHdr icon="📄">Output</SectionHdr>
      <Toggle label="Cramp to One Line" checked={opts.oneLine} onChange={so("oneLine")}/>
      <Toggle label="⚠ Anti-Tamper" checked={opts.antiTamper} onChange={so("antiTamper")} danger sub="May conflict with some environments"/>

      <div style={{ margin:"14px 0 4px",padding:"11px",background:"rgba(239,68,68,0.07)",borderRadius:9,border:`1px solid ${C.red}28`,fontSize:11,color:"#f87171",lineHeight:1.65 }}>
        ⚠ Encoding layers wrap the full script in a string loader via <code>load()</code>. This may trigger Roblox's executor detectors.
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
//  GITHUB PANEL
// ═══════════════════════════════════════════════════════════════

function GitHubPanel({ output, mobile }) {
  const [token, setToken] = useState(() => { try { return localStorage.getItem("gh_token")||""; } catch { return ""; }});
  const [user, setUser] = useState(null);
  const [repos, setRepos] = useState([]);
  const [branches, setBranches] = useState([]);
  const [selectedRepo, setSelectedRepo] = useState(null);
  const [selectedBranch, setSelectedBranch] = useState("");
  const [folder, setFolder] = useState("");
  const [fileName, setFileName] = useState("obfuscated_script.lua");
  const [commitMsg, setCommitMsg] = useState("Upload obfuscated script via Mr.Clod");
  const [status, setStatus] = useState(null); // {type, msg}
  const [uploadedUrl, setUploadedUrl] = useState(null);
  const [loading, setLoading] = useState("");
  const [showToken, setShowToken] = useState(false);
  const [folderContents, setFolderContents] = useState([]);
  const [copiedWhat, setCopiedWhat] = useState(null);

  const saveToken = (t) => { setToken(t); try { localStorage.setItem("gh_token", t); } catch {} };

  const connect = async () => {
    if (!token.trim()) { setStatus({type:"error",msg:"Please enter a GitHub token."}); return; }
    setLoading("Connecting...");
    try {
      const u = await getUser(token);
      setUser(u);
      const r = await getRepos(token);
      setRepos(r);
      setStatus({type:"success",msg:`Connected as @${u.login} · ${r.length} repos loaded`});
    } catch(e) { setStatus({type:"error",msg:e.message}); }
    setLoading("");
  };

  const disconnect = () => { setUser(null); setRepos([]); setBranches([]); setSelectedRepo(null); setSelectedBranch(""); setUploadedUrl(null); setStatus(null); setFolderContents([]); };

  const selectRepo = async (repo) => {
    setSelectedRepo(repo); setSelectedBranch(""); setBranches([]); setUploadedUrl(null); setFolderContents([]);
    setLoading("Loading branches...");
    try {
      const b = await getBranches(token, repo.owner.login, repo.name);
      setBranches(b);
      const def = b.find(x=>x.name==="main")||b.find(x=>x.name==="master")||b[0];
      if(def) setSelectedBranch(def.name);
    } catch(e) { setStatus({type:"error",msg:e.message}); }
    setLoading("");
  };

  const browseFolder = async () => {
    if (!selectedRepo||!selectedBranch) return;
    setLoading("Browsing...");
    try {
      const contents = await listFolder(token, selectedRepo.owner.login, selectedRepo.name, selectedBranch, folder);
      setFolderContents(Array.isArray(contents)?contents:[]);
    } catch(e) { setStatus({type:"error",msg:"Folder not found or empty."}); setFolderContents([]); }
    setLoading("");
  };

  const upload = async () => {
    if (!output) { setStatus({type:"error",msg:"No obfuscated output to upload."}); return; }
    if (!selectedRepo||!selectedBranch||!fileName.trim()) { setStatus({type:"error",msg:"Select repo, branch, and filename first."}); return; }
    const filePath = folder ? `${folder.replace(/\/$/,"")}/${fileName}` : fileName;
    setLoading("Uploading...");
    try {
      const sha = await getFileSha(token, selectedRepo.owner.login, selectedRepo.name, selectedBranch, filePath);
      await uploadFile(token, selectedRepo.owner.login, selectedRepo.name, selectedBranch, filePath, output, commitMsg, sha);
      const url = rawUrl(selectedRepo.owner.login, selectedRepo.name, selectedBranch, filePath);
      setUploadedUrl(url);
      setStatus({type:"success",msg:`Uploaded to ${selectedRepo.name}/${filePath}`});
      if(folder) browseFolder();
    } catch(e) { setStatus({type:"error",msg:e.message}); }
    setLoading("");
  };

  const copy = async (text, what) => {
    try { await navigator.clipboard.writeText(text); setCopiedWhat(what); setTimeout(()=>setCopiedWhat(null),2000); } catch {}
  };

  const col = mobile ? "column" : "column";

  return (
    <div style={{ display:"flex",flexDirection:"column",gap:14,height:"100%",overflowY:"auto",padding:"16px",WebkitOverflowScrolling:"touch" }}>
      {/* Header */}
      <div style={{ display:"flex",alignItems:"center",gap:10 }}>
        <div style={{ width:32,height:32,borderRadius:8,background:"#161b22",border:`1px solid ${C.border}`,display:"flex",alignItems:"center",justifyContent:"center",fontSize:18,flexShrink:0 }}>🐙</div>
        <div>
          <div style={{ fontSize:14,fontWeight:700 }}>GitHub Integration</div>
          <div style={{ fontSize:10,color:C.muted }}>Upload obfuscated scripts directly to your repos</div>
        </div>
        {user && (
          <div style={{ marginLeft:"auto",display:"flex",alignItems:"center",gap:8,flexShrink:0 }}>
            <img src={user.avatar_url} alt="" style={{ width:26,height:26,borderRadius:"50%",border:`1.5px solid ${C.accent}` }}/>
            <span style={{ fontSize:12,color:C.accent2,fontWeight:600 }}>@{user.login}</span>
            <button onClick={disconnect} style={{ background:"none",border:`1px solid ${C.border}`,color:C.muted,borderRadius:6,padding:"3px 8px",fontSize:11,cursor:"pointer",fontFamily:"inherit" }}>Sign out</button>
          </div>
        )}
      </div>

      {/* Status */}
      {status && (
        <div style={{ padding:"9px 12px",borderRadius:8,background:status.type==="success"?"#022c22":"#1c0808",border:`1px solid ${status.type==="success"?C.green+"44":C.red+"44"}`,fontSize:12,color:status.type==="success"?C.green:C.red,display:"flex",alignItems:"center",gap:6 }}>
          {status.type==="success"?"✓":"✗"} {status.msg}
        </div>
      )}

      {loading && (
        <div style={{ padding:"9px 12px",borderRadius:8,background:`${C.accent}15`,border:`1px solid ${C.accent}33`,fontSize:12,color:C.accent2 }}>
          ⚙ {loading}
        </div>
      )}

      {/* Token connect */}
      {!user ? (
        <div style={{ display:"flex",flexDirection:"column",gap:10,background:C.card,borderRadius:12,padding:"16px",border:`1px solid ${C.border}` }}>
          <div style={{ fontSize:13,fontWeight:600,color:C.text }}>Connect your GitHub account</div>
          <div style={{ fontSize:11,color:C.muted,lineHeight:1.6 }}>
            Create a token at <span style={{ color:C.cyan }}>github.com → Settings → Developer settings → Personal access tokens</span>.<br/>
            Required scopes: <code style={{ background:"#1a1a30",padding:"1px 5px",borderRadius:4,color:C.accent2 }}>repo</code>
          </div>
          <div style={{ display:"flex",gap:8,alignItems:"flex-end",flexWrap:"wrap" }}>
            <div style={{ flex:1,minWidth:200 }}>
              <Input label="Personal Access Token" value={token} onChange={saveToken} placeholder="ghp_xxxxxxxxxxxxxxxxxxxx" type={showToken?"text":"password"} mono/>
            </div>
            <button onClick={()=>setShowToken(p=>!p)} style={{ background:C.card2,border:`1px solid ${C.border}`,color:C.muted,borderRadius:9,padding:"10px 12px",fontSize:13,cursor:"pointer",fontFamily:"inherit",flexShrink:0,marginBottom:0 }}>
              {showToken?"🙈":"👁"}
            </button>
          </div>
          <button onClick={connect} style={{ background:C.accent,color:"#fff",border:"none",borderRadius:10,padding:"11px 0",fontSize:13,fontWeight:700,cursor:"pointer",fontFamily:"inherit",letterSpacing:0.5,transition:"background 0.2s" }}>
            🐙 Connect to GitHub
          </button>
        </div>
      ) : (
        <>
          {/* Repo list */}
          <div style={{ background:C.card,borderRadius:12,border:`1px solid ${C.border}`,overflow:"hidden" }}>
            <div style={{ padding:"10px 14px",borderBottom:`1px solid ${C.border}`,fontSize:12,fontWeight:600,color:C.muted,display:"flex",justifyContent:"space-between",alignItems:"center" }}>
              <span>📁 Your Repositories</span>
              <span style={{ color:C.dim,fontSize:11 }}>{repos.length} repos</span>
            </div>
            <div style={{ maxHeight:180,overflowY:"auto" }}>
              {repos.map(r => (
                <div
                  key={r.id}
                  onClick={()=>selectRepo(r)}
                  style={{ padding:"10px 14px",cursor:"pointer",borderBottom:`1px solid ${C.border}22`,background:selectedRepo?.id===r.id?`${C.accent}18`:"transparent",display:"flex",alignItems:"center",gap:10,transition:"background 0.1s" }}
                >
                  <span style={{ fontSize:14 }}>{r.private?"🔒":"📂"}</span>
                  <div style={{ flex:1,minWidth:0 }}>
                    <div style={{ fontSize:13,fontWeight:selectedRepo?.id===r.id?700:400,color:selectedRepo?.id===r.id?C.accent2:C.text,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap" }}>{r.full_name}</div>
                    {r.description && <div style={{ fontSize:10,color:C.muted,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap" }}>{r.description}</div>}
                  </div>
                  {selectedRepo?.id===r.id && <span style={{ color:C.accent,fontSize:14,flexShrink:0 }}>✓</span>}
                </div>
              ))}
            </div>
          </div>

          {/* Config */}
          {selectedRepo && (
            <div style={{ background:C.card,borderRadius:12,border:`1px solid ${C.border}`,padding:"14px",display:"flex",flexDirection:"column",gap:12 }}>
              <div style={{ fontSize:12,fontWeight:600,color:C.cyan }}>📋 Upload Configuration</div>

              {/* Branch */}
              <div>
                <div style={{ fontSize:10,color:C.muted,textTransform:"uppercase",letterSpacing:1.5,marginBottom:6 }}>Branch</div>
                <select value={selectedBranch} onChange={e=>setSelectedBranch(e.target.value)} style={{ width:"100%",background:C.card2,border:`1.5px solid ${C.border}`,color:C.text,padding:"9px 12px",borderRadius:8,fontSize:13,fontFamily:"inherit",cursor:"pointer",outline:"none",WebkitAppearance:"none" }}>
                  {branches.map(b=><option key={b.name} value={b.name}>{b.name}</option>)}
                </select>
              </div>

              {/* Folder */}
              <div>
                <div style={{ fontSize:10,color:C.muted,textTransform:"uppercase",letterSpacing:1.5,marginBottom:6 }}>Folder Path <span style={{ color:C.dim,textTransform:"none",letterSpacing:0 }}>(optional, e.g. scripts/obfuscated)</span></div>
                <div style={{ display:"flex",gap:6 }}>
                  <input value={folder} onChange={e=>setFolder(e.target.value)} placeholder="Leave blank for root" style={{ flex:1,background:C.card2,border:`1.5px solid ${C.border}`,color:C.text,padding:"9px 12px",borderRadius:8,fontSize:13,fontFamily:"'JetBrains Mono',monospace",outline:"none" }}/>
                  <button onClick={browseFolder} title="Browse folder" style={{ background:C.card2,border:`1.5px solid ${C.border}`,color:C.muted,borderRadius:8,padding:"9px 12px",cursor:"pointer",fontSize:13,flexShrink:0,fontFamily:"inherit" }}>📂</button>
                </div>
              </div>

              {/* Folder contents */}
              {folderContents.length > 0 && (
                <div style={{ background:C.card2,borderRadius:8,border:`1px solid ${C.border}`,maxHeight:120,overflowY:"auto" }}>
                  {folderContents.map(f=>(
                    <div key={f.sha} style={{ padding:"6px 12px",fontSize:12,color:C.muted,display:"flex",alignItems:"center",gap:8,borderBottom:`1px solid ${C.border}22` }}>
                      <span>{f.type==="dir"?"📁":"📄"}</span>
                      <span style={{ flex:1,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap" }}>{f.name}</span>
                      {f.type==="file" && f.name.endsWith(".lua") && (
                        <button onClick={()=>setFileName(f.name)} style={{ background:"none",border:"none",color:C.accent2,cursor:"pointer",fontSize:11,fontFamily:"inherit",padding:0 }}>use</button>
                      )}
                    </div>
                  ))}
                </div>
              )}

              {/* Filename */}
              <Input label="File Name" value={fileName} onChange={setFileName} placeholder="obfuscated_script.lua" mono/>

              {/* Commit message */}
              <Input label="Commit Message" value={commitMsg} onChange={setCommitMsg} placeholder="Upload obfuscated script via Mr.Clod"/>

              {/* Upload button */}
              <button
                onClick={upload}
                disabled={!!loading||!output}
                style={{ background:loading||!output?"#1a1a30":C.green,color:loading||!output?C.muted:"#fff",border:"none",borderRadius:10,padding:"12px 0",fontSize:13,fontWeight:700,cursor:loading||!output?"not-allowed":"pointer",fontFamily:"inherit",transition:"all 0.2s",letterSpacing:0.5 }}
              >
                {loading?"⚙ Uploading...":"⬆ Upload to GitHub"}
              </button>
              {!output && <div style={{ fontSize:11,color:C.muted,textAlign:"center",marginTop:-6 }}>Obfuscate a script first to enable upload</div>}
            </div>
          )}

          {/* Upload result */}
          {uploadedUrl && (
            <div style={{ background:C.card,borderRadius:12,border:`1.5px solid ${C.green}44`,padding:"14px",display:"flex",flexDirection:"column",gap:10 }}>
              <div style={{ fontSize:12,fontWeight:700,color:C.green }}>✓ Upload Successful!</div>

              {/* Raw URL */}
              <div>
                <div style={{ fontSize:10,color:C.muted,textTransform:"uppercase",letterSpacing:1.5,marginBottom:6 }}>Raw URL</div>
                <div style={{ display:"flex",gap:6,alignItems:"center" }}>
                  <div style={{ flex:1,background:C.card2,border:`1px solid ${C.border}`,borderRadius:8,padding:"8px 10px",fontSize:11,fontFamily:"'JetBrains Mono',monospace",color:C.cyan,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap" }}>{uploadedUrl}</div>
                  <button onClick={()=>copy(uploadedUrl,"raw")} style={{ background:`${C.cyan}18`,border:`1px solid ${C.cyan}44`,color:C.cyan,borderRadius:8,padding:"8px 12px",fontSize:12,fontWeight:600,cursor:"pointer",fontFamily:"inherit",flexShrink:0 }}>
                    {copiedWhat==="raw"?"✓":"Copy"}
                  </button>
                </div>
              </div>

              {/* Loadstring */}
              <div>
                <div style={{ fontSize:10,color:C.muted,textTransform:"uppercase",letterSpacing:1.5,marginBottom:6 }}>Loadstring (paste in executor)</div>
                <div style={{ display:"flex",gap:6,alignItems:"center" }}>
                  <div style={{ flex:1,background:C.card2,border:`1px solid ${C.border}`,borderRadius:8,padding:"8px 10px",fontSize:11,fontFamily:"'JetBrains Mono',monospace",color:C.accent2,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap" }}>
                    {loadstringSnippet(uploadedUrl)}
                  </div>
                  <button onClick={()=>copy(loadstringSnippet(uploadedUrl),"ls")} style={{ background:`${C.accent}18`,border:`1px solid ${C.accent}44`,color:C.accent2,borderRadius:8,padding:"8px 12px",fontSize:12,fontWeight:600,cursor:"pointer",fontFamily:"inherit",flexShrink:0 }}>
                    {copiedWhat==="ls"?"✓":"Copy"}
                  </button>
                </div>
              </div>

              {/* Open in GitHub */}
              <a href={`https://github.com/${selectedRepo.owner.login}/${selectedRepo.name}/blob/${selectedBranch}/${folder?folder+"/":""}${fileName}`} target="_blank" rel="noreferrer" style={{ fontSize:12,color:C.muted,textDecoration:"none",textAlign:"center",display:"block",padding:"4px 0" }}>
                🔗 View on GitHub →
              </a>
            </div>
          )}
        </>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
//  BRANDING WATERMARK OVERLAY (output area)
// ═══════════════════════════════════════════════════════════════

function BrandBadge() {
  return (
    <div style={{ position:"absolute",bottom:10,right:10,display:"flex",alignItems:"center",gap:5,background:"rgba(124,58,237,0.12)",border:`1px solid ${C.accent}33`,borderRadius:20,padding:"4px 10px",pointerEvents:"none",userSelect:"none" }}>
      <span style={{ fontSize:10,color:C.accent2,fontWeight:700,letterSpacing:0.5 }}>⬡ Obfuscated by Mr.Clod</span>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════
//  GLOBAL CSS
// ═══════════════════════════════════════════════════════════════

const GLOBAL_CSS = `
  @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&family=Space+Grotesk:wght@400;500;600;700&display=swap');
  *{box-sizing:border-box;margin:0;padding:0;}
  html{height:100%;overflow:hidden;}
  body{height:100%;background:${C.bg};color:${C.text};font-family:'Space Grotesk',sans-serif;-webkit-font-smoothing:antialiased;overflow:hidden;}
  ::-webkit-scrollbar{width:4px;height:4px;}
  ::-webkit-scrollbar-track{background:transparent;}
  ::-webkit-scrollbar-thumb{background:${C.accent}88;border-radius:4px;}
  textarea,pre{font-family:'JetBrains Mono',monospace!important;}
  textarea{font-size:14px!important;-webkit-user-select:text!important;user-select:text!important;}
  select,input{font-size:16px!important;}
  a{color:inherit;}
  button{-webkit-tap-highlight-color:transparent;touch-action:manipulation;}
  code{font-family:'JetBrains Mono',monospace;font-size:0.9em;}
  @keyframes fadeUp{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}
  @keyframes slideUp{from{transform:translateY(100%)}to{transform:translateY(0)}}
  @keyframes overlay{from{opacity:0}to{opacity:1}}
  .fade-up{animation:fadeUp 0.2s ease forwards;}
  .slide-up{animation:slideUp 0.28s cubic-bezier(0.32,0.72,0,1) forwards;}
  .overlay-in{animation:overlay 0.2s ease forwards;}
`;

// ═══════════════════════════════════════════════════════════════
//  MAIN APP
// ═══════════════════════════════════════════════════════════════

export default function App() {
  const [source, setSource] = useState(SAMPLE);
  const [output, setOutput] = useState("");
  const [opts, setOpts] = useState(DEFAULT_OPTS);
  // mobile tabs: "input" | "output" | "github"
  // desktop drawer: "settings" | "github" | null
  const [activeTab, setActiveTab] = useState("input");
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [ghOpen, setGhOpen] = useState(false);
  const [obfStatus, setObfStatus] = useState(null);
  const [copied, setCopied] = useState(null);
  const [processing, setProcessing] = useState(false);
  const [mobile, setMobile] = useState(false);
  const [desktopPanel, setDesktopPanel] = useState("settings"); // "settings" | "github"
  const drawerRef = useRef(null);

  useEffect(() => {
    const check = () => setMobile(window.innerWidth < 768);
    check();
    window.addEventListener("resize", check);
    return () => window.removeEventListener("resize", check);
  }, []);

  // Close sheet on outside tap
  useEffect(() => {
    if ((!settingsOpen && !ghOpen) || !mobile) return;
    const handler = (e) => { if (drawerRef.current && !drawerRef.current.contains(e.target)) { setSettingsOpen(false); setGhOpen(false); } };
    const t = setTimeout(() => document.addEventListener("touchstart", handler, {passive:true}), 50);
    return () => { clearTimeout(t); document.removeEventListener("touchstart", handler); };
  }, [settingsOpen, ghOpen, mobile]);

  const handleObfuscate = useCallback(() => {
    if (!source.trim()) { setObfStatus({type:"error",msg:"Input is empty."}); return; }
    setProcessing(true); setObfStatus(null);
    setTimeout(() => {
      const r = obfuscate(source, opts);
      if (r.success) {
        setOutput(r.code);
        setObfStatus({type:"success",msg:`Done! ${r.code.length} chars`});
        if (mobile) setActiveTab("output");
      } else setObfStatus({type:"error",msg:r.error});
      setProcessing(false);
    }, 80);
  }, [source, opts, mobile]);

  const handleCopy = (what) => {
    const text = what === "loadstring" && output ? `loadstring(game:HttpGet("YOUR_RAW_URL"))()` : output;
    navigator.clipboard.writeText(text).then(() => { setCopied(what); setTimeout(()=>setCopied(null),2000); });
  };

  // ── DESKTOP ────────────────────────────────────────────────────
  if (!mobile) {
    return (
      <>
        <style>{GLOBAL_CSS}</style>
        <div style={{ height:"100vh",display:"flex",flexDirection:"column" }}>
          {/* Header */}
          <div style={{ background:C.panel,borderBottom:`1px solid ${C.border}`,padding:"0 20px",height:52,display:"flex",alignItems:"center",gap:12,flexShrink:0 }}>
            <div style={{ width:30,height:30,borderRadius:8,background:C.accent,display:"flex",alignItems:"center",justifyContent:"center",fontSize:15,boxShadow:`0 0 14px ${C.accent}55`,flexShrink:0 }}>⬡</div>
            <div>
              <div style={{ fontSize:15,fontWeight:700,letterSpacing:0.3 }}>Mr.Clod</div>
              <div style={{ fontSize:9,color:C.muted,letterSpacing:2,textTransform:"uppercase" }}>Luau Obfuscator Engine</div>
            </div>
            <div style={{ marginLeft:"auto",display:"flex",gap:8,alignItems:"center" }}>
              <span style={{ fontSize:10,color:C.muted,padding:"3px 9px",background:"#1a1a2e",borderRadius:20,border:`1px solid ${C.border}` }}>Luau · Lua 5.4</span>
              <span style={{ fontSize:10,color:C.green,padding:"3px 9px",background:"#022c22",borderRadius:20,border:`1px solid ${C.green}44` }}>● ONLINE</span>
            </div>
          </div>

          <div style={{ flex:1,display:"flex",overflow:"hidden" }}>
            {/* Sidebar */}
            <div style={{ width:280,background:C.panel,borderRight:`1px solid ${C.border}`,display:"flex",flexDirection:"column",flexShrink:0,overflow:"hidden" }}>
              {/* Panel tabs */}
              <div style={{ display:"flex",borderBottom:`1px solid ${C.border}`,flexShrink:0 }}>
                {[["settings","⚙ Options"],["github","🐙 GitHub"]].map(([k,label])=>(
                  <button key={k} onClick={()=>setDesktopPanel(k)} style={{
                    flex:1,padding:"10px 0",fontSize:11,fontWeight:600,letterSpacing:0.5,
                    background:"transparent",border:"none",cursor:"pointer",fontFamily:"inherit",
                    color:desktopPanel===k?C.accent2:C.muted,
                    borderBottom:`2px solid ${desktopPanel===k?C.accent:"transparent"}`,transition:"color 0.15s",
                  }}>{label}</button>
                ))}
              </div>
              {/* Panel content */}
              <div style={{ flex:1,overflowY:"auto",padding:desktopPanel==="github"?"0":"0 14px 16px" }}>
                {desktopPanel === "settings" ? <SettingsPanel opts={opts} setOpts={setOpts}/> : <GitHubPanel output={output} mobile={false}/>}
              </div>
            </div>

            {/* Editors */}
            <div style={{ flex:1,display:"flex",flexDirection:"column",overflow:"hidden" }}>
              <div style={{ flex:1,display:"flex",overflow:"hidden" }}>
                {/* Input */}
                <div style={{ flex:1,display:"flex",flexDirection:"column",borderRight:`1px solid ${C.border}` }}>
                  <div style={{ padding:"7px 14px",background:"#090913",borderBottom:`1px solid ${C.border}`,display:"flex",alignItems:"center",justifyContent:"space-between",flexShrink:0 }}>
                    <span style={{ fontSize:11,color:C.muted,letterSpacing:1 }}>INPUT.luau</span>
                    <button onClick={()=>{setSource("");setOutput("");setObfStatus(null);}} style={{ fontSize:11,color:C.muted,background:"#1a1a30",border:"none",borderRadius:6,padding:"3px 10px",cursor:"pointer",fontFamily:"inherit" }}>Clear</button>
                  </div>
                  <textarea value={source} onChange={e=>setSource(e.target.value)} placeholder="-- Paste Luau script here..." spellCheck={false} style={{ flex:1,background:"transparent",border:"none",outline:"none",color:C.text,lineHeight:1.75,resize:"none",padding:"14px" }}/>
                </div>
                {/* Output */}
                <div style={{ flex:1,display:"flex",flexDirection:"column",position:"relative" }}>
                  <div style={{ padding:"7px 14px",background:"#090913",borderBottom:`1px solid ${C.border}`,display:"flex",alignItems:"center",gap:8,flexShrink:0 }}>
                    <span style={{ fontSize:11,color:C.muted,letterSpacing:1,flex:1 }}>OUTPUT.luau</span>
                    {output && <>
                      <button onClick={()=>handleCopy("output")} style={{ fontSize:11,color:copied==="output"?C.green:C.cyan,background:`${C.cyan}15`,border:`1px solid ${C.cyan}33`,borderRadius:6,padding:"3px 10px",cursor:"pointer",fontFamily:"inherit",fontWeight:600 }}>{copied==="output"?"✓ Copied":"Copy Raw"}</button>
                    </>}
                  </div>
                  <pre style={{ flex:1,overflow:"auto",padding:"14px",fontSize:11,lineHeight:1.75,color:output?"#a78bfa":C.muted,whiteSpace:"pre-wrap",wordBreak:"break-all" }}>{output||"// Output appears here..."}</pre>
                  {output && opts.branding && <BrandBadge/>}
                </div>
              </div>

              {/* Bottom bar */}
              <div style={{ padding:"9px 16px",background:C.panel,borderTop:`1px solid ${C.border}`,display:"flex",alignItems:"center",gap:10,flexShrink:0 }}>
                <button onClick={handleObfuscate} disabled={processing} style={{ background:processing?"#1e1e3a":C.accent,color:"#fff",border:"none",borderRadius:8,padding:"9px 24px",fontSize:13,fontWeight:700,cursor:processing?"not-allowed":"pointer",fontFamily:"inherit",letterSpacing:0.8,transition:"background 0.2s",boxShadow:processing?"none":`0 0 16px ${C.accent}44`,flexShrink:0 }}>
                  {processing?"⚙  Processing...":"⬡  OBFUSCATE"}
                </button>
                {obfStatus && (
                  <div className="fade-up" style={{ fontSize:12,padding:"6px 10px",borderRadius:6,background:obfStatus.type==="success"?"#022c22":"#1c0a0a",color:obfStatus.type==="success"?C.green:C.red,border:`1px solid ${obfStatus.type==="success"?C.green+"44":C.red+"44"}` }}>
                    {obfStatus.type==="success"?"✓":"✗"} {obfStatus.msg}
                  </div>
                )}
                <div style={{ marginLeft:"auto",display:"flex",gap:12,alignItems:"center" }}>
                  {source && <span style={{ fontSize:11,color:C.muted }}>{source.length} in</span>}
                  {output && <span style={{ fontSize:11,color:C.cyan }}>{output.length} out</span>}
                  {source && output && <span style={{ fontSize:11,color:C.yellow }}>{((output.length/source.length)*100).toFixed(0)}% ratio</span>}
                </div>
              </div>
            </div>
          </div>
        </div>
      </>
    );
  }

  // ── MOBILE ─────────────────────────────────────────────────────
  const sheetOpen = settingsOpen || ghOpen;

  return (
    <>
      <style>{GLOBAL_CSS}</style>
      <div style={{ height:"100dvh",display:"flex",flexDirection:"column",background:C.bg,overflow:"hidden",position:"relative" }}>

        {/* Header */}
        <div style={{ background:C.panel,borderBottom:`1px solid ${C.border}`,padding:"0 12px",height:50,display:"flex",alignItems:"center",gap:8,flexShrink:0,zIndex:10 }}>
          <div style={{ width:28,height:28,borderRadius:7,background:C.accent,display:"flex",alignItems:"center",justifyContent:"center",fontSize:14,boxShadow:`0 0 12px ${C.accent}55`,flexShrink:0 }}>⬡</div>
          <div style={{ flex:1,minWidth:0 }}>
            <div style={{ fontSize:14,fontWeight:700,lineHeight:1 }}>Mr.Clod</div>
            <div style={{ fontSize:8,color:C.muted,letterSpacing:1.5,textTransform:"uppercase" }}>Luau Obfuscator</div>
          </div>
          <button onClick={()=>{ setSettingsOpen(true); setGhOpen(false); }} style={{ background:C.card,border:`1px solid ${C.border}`,color:C.text,borderRadius:8,padding:"6px 10px",fontSize:11,fontWeight:600,fontFamily:"inherit",cursor:"pointer",flexShrink:0 }}>⚙ Options</button>
          <button onClick={()=>{ setGhOpen(true); setSettingsOpen(false); }} style={{ background:`${C.accent}20`,border:`1px solid ${C.accent}44`,color:C.accent2,borderRadius:8,padding:"6px 10px",fontSize:11,fontWeight:600,fontFamily:"inherit",cursor:"pointer",flexShrink:0 }}>🐙 GitHub</button>
        </div>

        {/* Tab bar */}
        <div style={{ display:"flex",background:C.card,borderBottom:`1px solid ${C.border}`,flexShrink:0 }}>
          {[["input","📥 Input"],["output","📤 Output"]].map(([tab,label])=>(
            <button key={tab} onClick={()=>setActiveTab(tab)} style={{
              flex:1,padding:"11px 0",fontSize:11,fontWeight:600,letterSpacing:0.8,textTransform:"uppercase",
              color:activeTab===tab?C.accent2:C.muted,borderBottom:`2.5px solid ${activeTab===tab?C.accent:"transparent"}`,
              background:"transparent",border:"none",cursor:"pointer",fontFamily:"inherit",display:"flex",alignItems:"center",justifyContent:"center",gap:5,
            }}>
              {label}
              {tab==="output"&&output&&<span style={{ background:C.accent,color:"#fff",borderRadius:10,fontSize:8,padding:"1px 5px",fontWeight:700 }}>READY</span>}
            </button>
          ))}
        </div>

        {/* Editor */}
        <div style={{ flex:1,display:"flex",flexDirection:"column",overflow:"hidden" }}>
          {activeTab==="input" ? (
            <>
              <div style={{ padding:"6px 12px",background:"#090913",borderBottom:`1px solid ${C.border}`,display:"flex",alignItems:"center",justifyContent:"space-between",flexShrink:0 }}>
                <span style={{ fontSize:10,color:C.muted }}>INPUT.luau · {source.length} chars</span>
                <button onClick={()=>{setSource("");setOutput("");setObfStatus(null);}} style={{ fontSize:11,color:C.muted,background:"#1a1a30",border:"none",borderRadius:6,padding:"3px 9px",cursor:"pointer",fontFamily:"inherit" }}>Clear</button>
              </div>
              <textarea value={source} onChange={e=>setSource(e.target.value)} placeholder={"-- Paste your Luau / Roblox script here..."} spellCheck={false} autoCorrect="off" autoCapitalize="off"
                style={{ flex:1,background:"transparent",border:"none",outline:"none",color:C.text,lineHeight:1.75,resize:"none",padding:"12px",WebkitOverflowScrolling:"touch",overflowY:"auto" }}/>
            </>
          ) : (
            <>
              <div style={{ padding:"6px 12px",background:"#090913",borderBottom:`1px solid ${C.border}`,display:"flex",alignItems:"center",gap:6,flexShrink:0 }}>
                <span style={{ fontSize:10,color:C.muted,flex:1 }}>OUTPUT.luau{output?` · ${output.length} chars`:""}</span>
                {output && <button onClick={()=>handleCopy("output")} style={{ fontSize:11,color:copied==="output"?C.green:C.cyan,background:`${C.cyan}15`,border:`1px solid ${C.cyan}33`,borderRadius:6,padding:"3px 10px",cursor:"pointer",fontFamily:"inherit",fontWeight:600 }}>{copied==="output"?"✓ Copied":"Copy"}</button>}
              </div>
              <div style={{ flex:1,overflow:"hidden",position:"relative" }}>
                <pre style={{ height:"100%",overflow:"auto",padding:"12px",fontSize:11,lineHeight:1.75,color:output?"#a78bfa":C.muted,whiteSpace:"pre-wrap",wordBreak:"break-all",WebkitOverflowScrolling:"touch" }}>
                  {output||"// Tap OBFUSCATE to generate output..."}
                </pre>
                {output && opts.branding && <BrandBadge/>}
              </div>
            </>
          )}
        </div>

        {/* Status */}
        {obfStatus && (
          <div className="fade-up" style={{ flexShrink:0,padding:"8px 12px",background:obfStatus.type==="success"?"#022c22":"#1c0808",borderTop:`1px solid ${obfStatus.type==="success"?C.green+"44":C.red+"44"}`,fontSize:12,color:obfStatus.type==="success"?C.green:C.red,display:"flex",alignItems:"center",gap:6 }}>
            {obfStatus.type==="success"?"✓":"✗"} {obfStatus.msg}
            {source&&output&&<span style={{ marginLeft:"auto",color:C.yellow,fontSize:11 }}>{((output.length/source.length)*100).toFixed(0)}% ratio</span>}
          </div>
        )}

        {/* Obfuscate button */}
        <div style={{ flexShrink:0,padding:"10px 12px",paddingBottom:"max(10px,env(safe-area-inset-bottom))",background:C.panel,borderTop:`1px solid ${C.border}` }}>
          <button onClick={handleObfuscate} disabled={processing} style={{ width:"100%",background:processing?"#1a1a30":C.accent,color:"#fff",border:"none",borderRadius:12,padding:"14px 0",fontSize:15,fontWeight:700,cursor:processing?"not-allowed":"pointer",fontFamily:"inherit",letterSpacing:0.8,transition:"all 0.2s",boxShadow:processing?"none":`0 0 20px ${C.accent}44` }}>
            {processing?"⚙  Processing...":"⬡  OBFUSCATE"}
          </button>
        </div>

        {/* Bottom sheet backdrop */}
        {sheetOpen && <div className="overlay-in" onClick={()=>{setSettingsOpen(false);setGhOpen(false);}} style={{ position:"fixed",inset:0,background:"rgba(0,0,0,0.75)",zIndex:50 }}/>}

        {/* Bottom sheet */}
        {sheetOpen && (
          <div ref={drawerRef} className="slide-up" style={{ position:"fixed",bottom:0,left:0,right:0,zIndex:60,background:C.panel,borderRadius:"18px 18px 0 0",border:`1px solid ${C.border}`,borderBottom:"none",maxHeight:"88dvh",display:"flex",flexDirection:"column" }}>
            {/* Handle */}
            <div style={{ flexShrink:0,padding:"12px 14px 8px",borderBottom:`1px solid ${C.border}` }}>
              <div style={{ width:36,height:4,background:C.border,borderRadius:2,margin:"0 auto 12px" }}/>
              <div style={{ display:"flex",alignItems:"center",justifyContent:"space-between" }}>
                <span style={{ fontSize:14,fontWeight:700 }}>{settingsOpen?"⚙ Obfuscation Options":"🐙 GitHub Integration"}</span>
                <button onClick={()=>{setSettingsOpen(false);setGhOpen(false);}} style={{ background:"none",border:"none",color:C.muted,fontSize:20,cursor:"pointer",padding:"0 4px",lineHeight:1 }}>×</button>
              </div>
            </div>
            {/* Content */}
            <div style={{ flex:1,overflowY:"auto",padding:ghOpen?"0":"4px 14px 16px",WebkitOverflowScrolling:"touch" }}>
              {settingsOpen && <SettingsPanel opts={opts} setOpts={setOpts}/>}
              {ghOpen && <GitHubPanel output={output} mobile={true}/>}
            </div>
            {/* Done */}
            {settingsOpen && (
              <div style={{ flexShrink:0,padding:"10px 14px",paddingBottom:"max(10px,env(safe-area-inset-bottom))",borderTop:`1px solid ${C.border}` }}>
                <button onClick={()=>setSettingsOpen(false)} style={{ width:"100%",background:C.accent,color:"#fff",border:"none",borderRadius:11,padding:"13px 0",fontSize:14,fontWeight:700,cursor:"pointer",fontFamily:"inherit" }}>Done</button>
              </div>
            )}
          </div>
        )}
      </div>
    </>
  );
}
