-- Run from repository root: luatex --luaonly tests/runback_routes.lua
-- Independent Dijkstra comparison of the defined hybrid graph, not a live terrain test.
local M=dofile('tests/wow_mock.lua')
local A={}
for _,path in ipairs({'Core','Data/Areas','Data/Graveyards','Data/Network','Areas','Graveyards','Routing'}) do assert(loadfile('RunBack/'..path..'.lua'))('VoidMark',A) end
assert(A:EnsureRouteData(), 'route diagnostics must load the graph')
local sqrt, max = math.sqrt, math.max
local function add(heap,node,cost)
 heap[#heap+1]={node=node,cost=cost};local i=#heap
 while i>1 and heap[i].cost<heap[math.floor(i/2)].cost do local p=math.floor(i/2);heap[i],heap[p]=heap[p],heap[i];i=p end
end
local function take(heap)
 local first=heap[1];local last=table.remove(heap)
 if #heap>0 then
  heap[1]=last;local i=1
  while i*2<=#heap do local c=i*2;if c+1<=#heap and heap[c+1].cost<heap[c].cost then c=c+1 end;if heap[i].cost<=heap[c].cost then break end;heap[i],heap[c]=heap[c],heap[i];i=c end
 end
 return first
end
local function segmentCost(n,m,p)
 local ax,ay=n[1]-p.x,n[2]-p.y;local vx,vy=m[1]-n[1],m[2]-n[2]
 if ax*ax+ay*ay<=1600 then return 0 end
 local len=sqrt(vx*vx+vy*vy);if len==0 then return nil end
 local along=-(ax*vx+ay*vy)/len
 local perp2=ax*ax+ay*ay-along*along
 if perp2>1600 then return nil end
 local entry=along-sqrt(max(0,1600-perp2))
 if entry>=0 and entry<=len then return entry end
end
local function oracle(start,goal)
 local dist,heap,ends={},{},{}
 for _,v in ipairs(A:NearbyNodes(start,80)) do dist[v.id]=v.d;add(heap,v.id,v.d) end
 for _,v in ipairs(A:NearbyNodes(goal,80)) do ends[v.id]=max(0,v.d-40) end
 local best
 while #heap>0 do
  local v=take(heap)
  if best and v.cost>=best then return best end
  if v.cost==dist[v.node] then
   local tail=ends[v.node];if tail then best=math.min(best or math.huge,v.cost+tail) end
   local n=A.Data.nodes[v.node];local nexts={}
   for _,id in ipairs(n[5]) do local m=A.Data.nodes[id];if m and m[3]==n[3] then nexts[id]=sqrt((m[1]-n[1])^2+(m[2]-n[2])^2) end end
   for _,c in ipairs(A:LocalConnectors(v.node)) do nexts[c.id]=math.min(nexts[c.id] or math.huge,c.d) end
   for id,cost in pairs(nexts) do
    local m=A.Data.nodes[id];local hit=segmentCost(n,m,goal)
    if hit then best=math.min(best or math.huge,v.cost+hit) end
    local value=v.cost+cost
    if not dist[id] or value<dist[id]-1e-9 then dist[id]=value;add(heap,id,value) end
   end
  end
 end
 return best
end
for _,pair in ipairs({{10,3},{44,104},{11,7},{267,149},{33,389}}) do
 M.timers={};local zone,id=pair[1],pair[2];local gy=A.Data.graveyards[id];local p
 for _,n in ipairs(A.Data.nodes) do
  if n[3]==gy.map and n[4]==zone then local d=A:Distance({x=n[1],y=n[2],map=n[3]},gy);if d>300 and d<600 then p={x=n[1],y=n[2],map=n[3],uncertainty=0};break end end
 end
 assert(p);local expected=oracle(gy,p);local called=false;local accepted,status
 A:RequestRoute(gy,p,function(distance,reason) called=true;accepted=distance;status=reason end)
 local ticks=0
 while not called and ticks<10000 do M.advance(.021);ticks=ticks+1 end
 assert(called,'route did not complete')
 local key=gy.map..':'..string.format('%.3f,%.3f:%.3f,%.3f',gy.x,gy.y,p.x,p.y)
 local actual=A.routeCache[key]
 assert((actual==nil and expected==nil) or (actual and expected and math.abs(actual-expected)<1e-5),'A*/Dijkstra disagreement in zone '..zone)
 print(string.format('ROUTE_ORACLE zone=%d gy=%d raw_yd=%s oracle_yd=%s accepted=%s slices=%d status=%s',zone,id,tostring(actual),tostring(expected),tostring(accepted),ticks,tostring(status)))
end
print('PASS: five actual-data hybrid routes agree with an independent Dijkstra oracle; this does not verify current Era terrain or graveyard assignments.')
